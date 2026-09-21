# frozen_string_literal: true

# One employee's ACL standing, worked out from an employee id alone: the
# groups they belong to, where they sit in the org chart, and the permission
# keys those grant. ApplicationController asks this for the signed-in user;
# a background job asks it for whoever set the job up, because a job has no
# session to read -- a scheduled Records export confirms on every run that its
# owner may still see the table.
#
# The readers keep ApplicationController's `current_user_*` names so shared
# rules such as RecordTableAccess read the same from either side. Every lookup
# is memoized and, like the controller's, falls back to "no access" rather
# than raising.
class EmployeePermissions
  include RecordTableAccess

  attr_reader :employee_id

  def initialize(employee_id)
    @employee_id = employee_id.presence
  end

  def system_admin?
    current_user_group_names.include?('system_admins')
  end

  # Group names (lowercased Set) the employee belongs to.
  def current_user_group_names
    load_groups unless defined?(@group_names)
    @group_names
  end

  def current_user_group_ids
    load_groups unless defined?(@group_ids)
    @group_ids
  end

  def current_user_org_chain
    return @org_chain if defined?(@org_chain)

    @org_chain = employee_id.present? ? resolve_org_chain : {}
  rescue StandardError
    @org_chain = {}
  end

  # Permission keys of one ACL type ('dropdown', 'record_view', ...).
  def keys(permission_type)
    (@keys ||= {})[permission_type.to_s] ||= Pfa::Access::PermissionSet.new(
      org_chain: current_user_org_chain,
      group_ids: current_user_group_ids
    ).keys(permission_type)
  end

  def current_user_dropdown_permissions = keys('dropdown')
  def current_user_record_view_permission_keys = keys('record_view')
  def current_user_record_edit_permission_keys = keys('record_edit')

  private

  def load_groups
    @group_names = Set.new
    @group_ids = []
    return if employee_id.blank?

    EmployeeGroup.joins(:group)
                 .where(EmployeeID: employee_id)
                 .pluck('Groups.Group_Name', 'Employee_Groups.GroupID')
                 .each do |group_name, group_id|
      @group_names << group_name.downcase
      @group_ids << group_id
    end
  rescue StandardError
    @group_names = Set.new
    @group_ids = []
  end

  # agency_id comes straight off the Employee row, normalized to the
  # three-character id the org tables and org_permissions use — Employees
  # stores a four-character variant ("HCAV" for "HCA") that matches no ACL
  # row on its own. The Unit lookup is only used for the deeper FKs — and is
  # often missing in GSABSS (e.g. unit "C480" exists on Employees but not in
  # Units), which previously zeroed out the whole chain and skipped every
  # org-level grant in load_user_permissions.
  def resolve_org_chain
    employee = Submitter.resolve(employee_id)
    unit     = Coa::Unit.resolve_for_employee(employee)

    {
      agency_id: Coa::Agency.normalize_id(employee&.agency),
      division_id: unit&.division_id,
      department_id: unit&.department_id,
      unit_id: unit&.unit_id
    }
  end
end
