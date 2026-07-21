# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :set_current_user
  helper_method :current_user, :inbox_count, :current_user_group_names, :current_user_group_ids, :current_user_org_chain,
                :auth_console_admin?, :auth_console_user?, :pcard_admin?, :current_user_dropdown_permissions,
                :current_user_form_permission_keys, :current_user_application_permission_keys,
                :current_user_record_edit_permission_keys

  def current_user
    user_data = session[:user]
    return nil unless user_data&.dig('employee_id') && user_data['email']

    @current_user ||= SessionUser.new(
      employee_id: user_data['employee_id'],
      email: user_data['email'],
      first_name: user_data['first_name'],
      last_name: user_data['last_name']
    )
  end

  # Number of items in the signed-in user's inbox, for the profile/tab badges.
  # Runs the same InboxQuery the inbox page uses (scoped to the user's own
  # queue), so the badge always matches the page and never clears on viewing.
  # Memoized per request — the badge renders more than once.
  def inbox_count
    return @inbox_count if defined?(@inbox_count)

    user = session[:user]
    @inbox_count =
      if user && user['employee_id'].present?
        InboxQuery.new(scoped_employee_ids: [user['employee_id'].to_s]).count
      else
        0
      end
  end

  def build_prefill_data(employee_id)
    employee = Submitter.resolve(employee_id)
    return {} unless employee

    unit = Unit.resolve_for_employee(employee)
    department = Department.find_by(department_id: unit&.department_id)
    division   = Division.find_by(division_id: department&.division_id)
    agency     = Agency.find_by(agency_id: division&.agency_id)

    {
      employee_id: employee.employee_id,
      name: "#{employee.first_name} #{employee.last_name}",
      phone: employee.work_phone,
      email: employee.email,
      agency: agency&.agency_id,
      division: division&.division_id,
      department: department&.department_id,
      unit: unit ? "#{unit.unit_id} - #{unit.long_name}" : nil
    }
  end

  # Memoized group names (Set) and group IDs (Array) for the current user.
  # Loaded once per request via a single JOIN query.
  def current_user_group_names
    load_current_user_groups unless defined?(@_current_user_group_names)
    @_current_user_group_names
  end

  def current_user_group_ids
    load_current_user_groups unless defined?(@_current_user_group_ids)
    @_current_user_group_ids
  end

  def current_user_org_chain
    return @_current_user_org_chain if defined?(@_current_user_org_chain)

    employee_id = session.dig(:user, 'employee_id')
    if employee_id.present?
      employee = Submitter.resolve(employee_id)
      unit     = Unit.resolve_for_employee(employee)

      # agency_id comes straight off the Employee row (validated to match
      # Agency.agency_id by EmployeeDataValidator). The Unit lookup is only used
      # for the deeper FKs — and is often missing in GSABSS (e.g. unit "C480"
      # exists on Employees but not in Units), which previously zeroed out the
      # whole chain and skipped every org-level grant in load_user_permissions.
      @_current_user_org_chain = {
        agency_id: employee&.agency,
        division_id: unit&.division_id,
        department_id: unit&.department_id,
        unit_id: unit&.unit_id
      }
    else
      @_current_user_org_chain = {}
    end
  rescue StandardError
    @_current_user_org_chain = {}
  end

  def auth_console_admin?
    current_user_group_names.include?('system_admins') ||
      current_user_group_names.include?('auth_console_admin')
  end

  def auth_console_user?
    auth_console_admin? ||
      current_user_group_names.include?('auth_console_approvers')
  end

  def pcard_admin?
    current_user_group_names.include?('system_admins') ||
      current_user_group_names.include?('pcard_admin')
  end

  def current_user_dropdown_permissions
    return @current_user_dropdown_permissions if defined?(@current_user_dropdown_permissions)

    @current_user_dropdown_permissions = load_user_permissions('dropdown')
  end

  def current_user_form_permission_keys
    return @current_user_form_permission_keys if defined?(@current_user_form_permission_keys)

    @current_user_form_permission_keys = load_user_permissions('form')
  end

  def current_user_application_permission_keys
    return @current_user_application_permission_keys if defined?(@current_user_application_permission_keys)

    @current_user_application_permission_keys = load_user_permissions('application')
  end

  # Records tables this user may edit inline, keyed by registry slug. Viewing a
  # grid and editing it are separate grants: a table's view permission says
  # nothing about whether its rows may be rewritten.
  def current_user_record_edit_permission_keys
    return @current_user_record_edit_permission_keys if defined?(@current_user_record_edit_permission_keys)

    @current_user_record_edit_permission_keys = load_user_permissions('record_edit')
  end

  def require_system_admin
    return if current_user_group_names.include?('system_admins')

    redirect_to root_path, alert: 'Access denied. System administrators only.'
  end

  # Gate an Admin-portal screen on its ACL grant. System admins get everything;
  # everyone else needs the matching "dropdown" permission key. This is the same
  # test ApplicationHelper#can_view_admin_tab? uses to decide whether to render
  # the tab, so a tab a user can see is always a tab they can open.
  def require_admin_tab(key)
    return if current_user_group_names.include?('system_admins')
    return if current_user_dropdown_permissions.include?(key)

    redirect_to root_path, alert: 'Access denied.'
  end

  def require_auth_console
    return if auth_console_user?

    redirect_to root_path, alert: 'Access denied. Authorization Console access required.'
  end

  private

  def update_trackable_status(record, new_status)
    status = new_status.to_s
    return false unless record.class.respond_to?(:statuses)
    return false unless record.class.statuses.key?(status)

    record.update(status: status)
  end

  def application_record_class_named(class_name)
    Rails.application.eager_load! unless Rails.application.config.eager_load

    ApplicationRecord.descendants.find { |model_class| model_class.name == class_name.to_s }
  end

  def load_current_user_groups
    employee_id = session.dig(:user, 'employee_id')

    if employee_id.present?
      rows = EmployeeGroup.joins(:group)
                          .where(EmployeeID: employee_id)
                          .pluck('Groups.Group_Name', 'Employee_Groups.GroupID')

      names = Set.new
      ids   = []
      rows.each do |group_name, group_id|
        names << group_name.downcase
        ids   << group_id
      end

      @_current_user_group_names = names
      @_current_user_group_ids   = ids
    else
      @_current_user_group_names = Set.new
      @_current_user_group_ids   = []
    end
  rescue StandardError
    @_current_user_group_names = Set.new
    @_current_user_group_ids   = []
  end

  def load_user_permissions(permission_type)
    keys = Set.new

    # 1. Global permissions (all org fields nil — apply to everyone)
    keys.merge(
      OrgPermission.where(
        agency_id: nil, division_id: nil, department_id: nil, unit_id: nil,
        permission_type: permission_type
      ).pluck(:permission_key)
    )

    # 2. Org-level permissions (cascading: agency → division → department → unit)
    org = current_user_org_chain
    if org[:agency_id].present?
      conditions = [
        { agency_id: org[:agency_id], division_id: nil, department_id: nil, unit_id: nil }
      ]
      conditions << { agency_id: org[:agency_id], division_id: org[:division_id], department_id: nil, unit_id: nil } if org[:division_id].present?
      conditions << { agency_id: org[:agency_id], division_id: org[:division_id], department_id: org[:department_id], unit_id: nil } if org[:department_id].present?
      conditions << { agency_id: org[:agency_id], division_id: org[:division_id], department_id: org[:department_id], unit_id: org[:unit_id] } if org[:unit_id].present?

      query = conditions.map { |c| OrgPermission.where(c.merge(permission_type: permission_type)) }.reduce(:or)
      keys.merge(query.pluck(:permission_key))
    end

    # 3. Group-level permissions (additive on top of org)
    group_ids = current_user_group_ids
    if group_ids.any?
      keys.merge(
        GroupPermission.where(group_id: group_ids, permission_type: permission_type)
                       .pluck(:permission_key)
      )
    end

    keys
  rescue StandardError
    Set.new
  end

  def set_current_user
    Current.user = session[:user]
  end
end
