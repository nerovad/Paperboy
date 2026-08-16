# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :set_current_user
  helper_method :current_user, :inbox_count, :current_user_group_names, :current_user_group_ids, :current_user_org_chain,
                :auth_console_admin?, :auth_console_user?, :pcard_admin?, :current_user_dropdown_permissions,
                :current_user_form_permission_keys, :current_user_application_permission_keys,
                :current_user_feature_permission_keys,
                :current_user_record_view_permission_keys, :current_user_record_edit_permission_keys,
                :safety_auth_console_user?,
                :available_authorization_consoles, :authorization_console_accessible?

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

      # agency_id comes straight off the Employee row, normalized to the
      # three-character id the org tables and org_permissions use — Employees
      # stores a four-character variant ("HCAV" for "HCA") that matches no ACL
      # row on its own. The Unit lookup is only used for the deeper FKs — and is
      # often missing in GSABSS (e.g. unit "C480" exists on Employees but not in
      # Units), which previously zeroed out the whole chain and skipped every
      # org-level grant in load_user_permissions.
      @_current_user_org_chain = {
        agency_id: Agency.normalize_id(employee&.agency),
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

  # Who may manage the Safety Reporting authorization console. Deliberately its
  # own group rather than the GSA console's — holding a parking/badge
  # authorization says nothing about who assigns HCA safety officers.
  def safety_auth_console_user?
    current_user_group_names.include?('system_admins') ||
      current_user_group_names.include?('safety_auth_console')
  end

  # The authorization consoles this user may open, in registry order. Drives
  # the form picker on the console entry screen and the switcher inside it.
  def available_authorization_consoles
    @available_authorization_consoles ||=
      AuthorizationConsole::ALL.select { |console| authorization_console_accessible?(console) }
  end

  def authorization_console_accessible?(console)
    case console.key
    when AuthorizationConsole::SERVICES.key   then auth_console_user?
    when AuthorizationConsole::HCA_SAFETY.key then safety_auth_console_user?
    else false
    end
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

  # Individual controls inside a sub-application — Billing's "Run Billing"
  # button, a Chart of Accounts table, an Admin Tools screen — keyed
  # "<app_key>:<feature_key>". See AppFeature for the catalog. The application
  # grant gets you into the app; these decide what you can do once inside.
  def current_user_feature_permission_keys
    return @current_user_feature_permission_keys if defined?(@current_user_feature_permission_keys)

    @current_user_feature_permission_keys = load_user_permissions('feature')
  end

  # Records tables this user may open, keyed by registry slug. This is the only
  # grant surface for form-backed tables, which declare neither a group
  # permission nor a dropdown key; model-backed tables can also be reached
  # through those older routes.
  def current_user_record_view_permission_keys
    return @current_user_record_view_permission_keys if defined?(@current_user_record_view_permission_keys)

    @current_user_record_view_permission_keys = load_user_permissions('record_view')
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

  # Gate one control inside a sub-application on its ACL grant. This is the
  # same test the sidebar uses to decide whether to render the button, so a
  # button a user can see is always one they can open — and a URL typed by
  # hand is refused just the same.
  #
  # +fallback+ is where a refused request lands; pass the app's own root so a
  # user who holds the app but not this screen is not thrown all the way back
  # to Paperboy.
  def require_app_feature(app_key, feature_key, fallback: root_path)
    return if helpers.can_use_app_feature?(app_key, feature_key)

    redirect_to fallback, alert: 'Access denied.'
  end

  # Gate an Admin Tools screen. Kept as its own name because five controllers
  # call it; it is now just the Admin Tools spelling of +require_app_feature+,
  # which still honours the legacy "dropdown" grants these screens shipped with.
  def require_admin_tab(key)
    require_app_feature('admin_tools', key)
  end

  def require_auth_console
    return if auth_console_user?

    redirect_to root_path, alert: 'Access denied. Authorization Console access required.'
  end

  def require_safety_auth_console
    return if safety_auth_console_user?

    redirect_to root_path, alert: 'Access denied. Authorization Console access required.'
  end

  # Gate for the console picker itself: any one console is enough to get in.
  def require_any_authorization_console
    return if available_authorization_consoles.any?

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
    Pfa::Access::PermissionSet.new(
      org_chain: current_user_org_chain,
      group_ids: current_user_group_ids
    ).keys(permission_type)
  end

  def set_current_user
    Current.user = session[:user]
  end
end
