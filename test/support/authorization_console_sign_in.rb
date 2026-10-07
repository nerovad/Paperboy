# frozen_string_literal: true

# Signs a controller test in to the parking, badges and keys console.
module AuthorizationConsoleSignIn
  Department = Struct.new(:department_id, :long_name)

  # Two departments, each with one unit and one employee.
  UNITS     = { '4601' => '4600', '5501' => '5500' }.freeze
  EMPLOYEES = { '100' => '4600', '200' => '5500' }.freeze

  # Signs in holding exactly the given console ACL keys, sitting in +own+
  # department. +admin+ is the auth_console_admin group, which reaches every
  # department. Assigned departments come from AuthorizationManager rows, which
  # the test creates itself. The org and employee lookups cross to GSABSS, so
  # they are answered from the tables above rather than the database.
  def sign_in_to_console(keys, own: nil, admin: false, employee_id: 1)
    session[:user] = { 'employee_id' => employee_id, 'email' => 'employee@example.com' }
    granted = keys.to_set
    departments = UNITS.values.uniq.map { |id| Department.new(id, "Department #{id}") }
    @controller = @controller.class.new

    stub_console(:current_user_group_names) { admin ? Set['auth_console_admin'] : Set.new }
    stub_console(:current_user_org_chain) { { department_id: own } }
    stub_console(:current_user_authorization_console_keys) { granted }
    stub_console(:all_departments) { departments }
    stub_console(:find_departments) { |ids| departments.select { |d| ids.include?(d.department_id) } }
    stub_console(:employees_in_departments) do |ids|
      EMPLOYEES.select { |_id, department| ids.include?(department) }
               .keys.map { |id| { id: id, name: "Employee #{id}", email: nil } }
    end
    stub_gsabss_units
  end

  private

  def stub_console(name, &block)
    @controller.define_singleton_method(name, &block)
  end

  # Only the approver console looks units up; the managers screen has none.
  def stub_gsabss_units
    return unless @controller.is_a?(AuthorizationConsoleController)

    stub_console(:units_by_department) do |ids|
      UNITS.select { |_unit, department| ids.include?(department) }
           .group_by(&:last).transform_values { |pairs| pairs.map(&:first) }
    end
    stub_console(:fetch_managed_budget_units) do
      UNITS.select { |_unit, department| department_ids_with('write').include?(department) }
           .keys.map { |unit| [unit, unit] }
    end
    stub_console(:resolve_department_from_units) do |approver|
      unit = approver.budget_units.to_s.split(',').first
      approver.department_id = AuthorizationConsoleSignIn::UNITS.fetch(unit) if unit.present?
    end
  end
end
