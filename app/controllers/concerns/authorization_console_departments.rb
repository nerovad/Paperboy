# frozen_string_literal: true

# Which departments the signed-in user reaches in the parking, badges and keys
# console, and what they may do in each.
#
# Two sources, merged per department:
#
# - The ACL. Its rights apply to the user's own department, or to every
#   department for an auth_console_admin.
# - AuthorizationManager. An assigned department carries every right, with no
#   ACL grant behind it.
#
# So rights are a per-department question. The console-level gate
# (require_auth_console) only says whether a user holds a right somewhere;
# every query and write here narrows to the departments where they hold it.
module AuthorizationConsoleDepartments
  extend ActiveSupport::Concern

  included do
    helper_method :department_right?, :departments_with, :manager_admin_departments
  end

  private

  def set_managed_departments
    assigned = assigned_department_ids
    acl_rights = authorization_console_acl_rights(AuthorizationConsole::SERVICES)
    everything = auth_console_admin? && acl_rights.include?('read')
    own = acl_rights.include?('read') ? [current_user_org_chain[:department_id]].compact.map(&:to_s) : []

    @managed_departments = everything ? all_departments : find_departments(own | assigned)
    @department_rights = @managed_departments.to_h do |department|
      id = department.department_id.to_s
      rights = everything || own.include?(id) ? acl_rights.dup : Set.new
      rights.merge(AuthorizationConsole::RIGHT_KEYS) if assigned.include?(id)
      [id, rights]
    end
  end

  def department_right?(department_id, right)
    @department_rights.fetch(department_id.to_s, Set.new).include?(right.to_s)
  end

  def departments_with(right)
    @managed_departments.select { |department| department_right?(department.department_id, right) }
  end

  def department_ids_with(right)
    departments_with(right).map { |department| department.department_id.to_s }
  end

  # The departments whose list of managers this user may change: the ones they
  # are assigned to, or all of them for an admin. Holding the ACL grant over
  # your own department does not make you its manager.
  def manager_admin_departments
    return @managed_departments if auth_console_admin?

    @managed_departments.select { |department| assigned_department_ids.include?(department.department_id.to_s) }
  end

  def assigned_department_ids
    @assigned_department_ids ||= AuthorizationManager.department_ids_for(current_employee_id)
  end

  def current_employee_id
    session.dig(:user, 'employee_id').to_s
  end

  # GSABSS departments table has duplicate rows; collapse by department_id.
  def all_departments
    Coa::Department.order(:department_id).to_a.uniq(&:department_id)
  end

  def find_departments(department_ids)
    return [] if department_ids.empty?

    Coa::Department.where(department_id: department_ids).order(:department_id).to_a.uniq(&:department_id)
  end

  # { department_id => [unit_id, ...] } for the given departments. GSABSS units
  # has duplicate rows, so each unit is listed once per department.
  def units_by_department(department_ids)
    return {} if department_ids.empty?

    pairs = Coa::Unit.where(department_id: department_ids).pluck(:department_id, :unit_id)
    pairs.map { |department_id, unit_id| [department_id.to_s, unit_id.to_s] }
         .uniq.sort.group_by(&:first).transform_values { |rows| rows.map(&:last) }
  end

  # Employee id => full name, for lists that name people by stored id.
  def employee_names_by_id(employee_ids)
    Employee.where(id: employee_ids.uniq).to_h { |employee| [employee.id.to_s, employee.full_name] }
  end

  # Everyone working in a unit of the given departments, as picker rows.
  def employees_in_departments(department_ids)
    return [] if department_ids.empty?

    unit_ids = Coa::Unit.where(department_id: department_ids).pluck(:unit_id)
    Employee.where(unit: unit_ids).order(:last_name, :first_name).map do |employee|
      { id: employee.employee_id, name: employee.name_with_id, email: employee.email }
    end
  end
end
