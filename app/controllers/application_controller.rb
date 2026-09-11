# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :set_current_user
  helper_method :current_user, :inbox_count, :current_user_group_names, :current_user_group_ids, :current_user_org_chain,
                :auth_console_admin?, :pcard_admin?, :current_user_dropdown_permissions,
                :current_user_form_permission_keys, :current_user_application_permission_keys,
                :current_user_feature_permission_keys,
                :current_user_record_view_permission_keys, :current_user_record_edit_permission_keys,
                :current_user_submission_action_permission_keys,
                :available_authorization_consoles, :authorization_console_accessible?,
                :authorization_console_rights, :can_read_authorization_console?,
                :can_write_authorization_console?, :can_delete_authorization_console?

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
        Forms::InboxQuery.new(scoped_employee_ids: [user['employee_id'].to_s]).count
      else
        0
      end
  end

  def build_prefill_data(employee_id)
    employee = Submitter.resolve(employee_id)
    return {} unless employee

    unit = Coa::Unit.resolve_for_employee(employee)
    department = Coa::Department.find_by(department_id: unit&.department_id)
    division   = Coa::Division.find_by(division_id: department&.division_id)
    agency     = Coa::Agency.find_by(agency_id: division&.agency_id)

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
      unit     = Coa::Unit.resolve_for_employee(employee)

      # agency_id comes straight off the Employee row, normalized to the
      # three-character id the org tables and org_permissions use — Employees
      # stores a four-character variant ("HCAV" for "HCA") that matches no ACL
      # row on its own. The Unit lookup is only used for the deeper FKs — and is
      # often missing in GSABSS (e.g. unit "C480" exists on Employees but not in
      # Units), which previously zeroed out the whole chain and skipped every
      # org-level grant in load_user_permissions.
      @_current_user_org_chain = {
        agency_id: Coa::Agency.normalize_id(employee&.agency),
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

  # Whether the parking/badge/key console shows every department or only the
  # user's own. A scope question, not an access one — access is the ACL grants
  # below. Kept on the group name because there is nowhere else to say it.
  def auth_console_admin?
    current_user_group_names.include?('system_admins') ||
      current_user_group_names.include?('auth_console_admin')
  end

  def pcard_admin?
    current_user_group_names.include?('system_admins') ||
      current_user_group_names.include?('pcard_admin')
  end

  # Console access is granted per console in ACL > Authorization Consoles, as
  # "<console>:<right>" keys. The old per-console group names
  # (auth_console_approvers, safety_auth_console, cir_auth_console) no longer
  # grant anything; system_admins keeps blanket access so the ACL can always be
  # reached to set the rest up.
  def current_user_authorization_console_keys
    return @current_user_authorization_console_keys if defined?(@current_user_authorization_console_keys)

    @current_user_authorization_console_keys = load_user_permissions(AuthorizationConsole::PERMISSION_TYPE)
  end

  def authorization_console_superuser?
    current_user_group_names.include?('system_admins')
  end

  # The rights this user holds on one console. Write and delete each imply read,
  # so ticking write alone in the ACL still lets them in to use it.
  def authorization_console_rights(console)
    key = console.respond_to?(:key) ? console.key : console.to_s
    return AuthorizationConsole::RIGHT_KEYS.to_set if authorization_console_superuser?

    AuthorizationConsole.rights_from_keys(key, current_user_authorization_console_keys)
  end

  def can_read_authorization_console?(console)
    authorization_console_rights(console).include?('read')
  end

  def can_write_authorization_console?(console)
    authorization_console_rights(console).include?('write')
  end

  def can_delete_authorization_console?(console)
    authorization_console_rights(console).include?('delete')
  end

  # The authorization consoles this user may open, in registry order. Drives
  # the form picker on the console entry screen and the switcher inside it.
  def available_authorization_consoles
    @available_authorization_consoles ||=
      AuthorizationConsole::ALL.select { |console| authorization_console_accessible?(console) }
  end

  def authorization_console_accessible?(console)
    can_read_authorization_console?(console)
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

  # Actions a viewer may take on a submission that isn't theirs to begin with,
  # keyed "<action>:<FormClass>" — see Forms::SubmissionPolicy. Granted per
  # group (ACL > group > permissions) or to everyone in an org node (ACL >
  # Organization Permissions); both flow through the same cascade below.
  def current_user_submission_action_permission_keys
    return @current_user_submission_action_permission_keys if defined?(@current_user_submission_action_permission_keys)

    @current_user_submission_action_permission_keys =
      load_user_permissions(Forms::SubmissionPolicy::PERMISSION_TYPE)
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

  # Gate a console screen on one right. Read sends you out of the console
  # entirely; write and delete send you back to the console you are already in,
  # because you can see it — you just cannot do that to it.
  def require_authorization_console(console, right = 'read')
    return if authorization_console_rights(console).include?(right)

    if right == 'read'
      redirect_to root_path, alert: 'Access denied. Authorization Console access required.'
    else
      redirect_to public_send(console.route_name), alert: "Access denied. You do not have #{right} access to this console."
    end
  end

  # Gate a screen that more than one right can reach — the CIR console's
  # add/edit pages, which carry the form for write and the removal buttons for
  # delete, and so must open for either.
  def require_authorization_console_any(console, *rights)
    return if authorization_console_rights(console).intersect?(rights.to_set)

    redirect_to public_send(console.route_name), alert: 'Access denied. You do not have access to that.'
  end

  def require_auth_console(right = 'read')
    require_authorization_console(AuthorizationConsole::SERVICES, right)
  end

  def require_safety_auth_console(right = 'read')
    require_authorization_console(AuthorizationConsole::HCA_SAFETY, right)
  end

  def require_cir_auth_console(right = 'read')
    require_authorization_console(AuthorizationConsole::CIR, right)
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
