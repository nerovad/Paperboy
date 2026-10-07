# frozen_string_literal: true

# Signs a controller test in to the parking, badges and keys console.
module AuthorizationConsoleSignIn
  Department = Struct.new(:department_id, :long_name)

  # Two departments, each with one unit and one employee.
  UNITS     = { '4601' => '4600', '5501' => '5500' }.freeze
  EMPLOYEES = { '100' => '4600', '200' => '5500' }.freeze

  # Signs in holding exactly the given console keys and managing exactly the
  # given departments. The org and employee lookups cross to GSABSS, so they
  # are answered from the tables above rather than the database.
  def sign_in_to_console(keys, departments:)
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com' }
    granted = keys.to_set
    managed = departments.map { |id| Department.new(id, "Department #{id}") }
    units = UNITS.select { |_unit, department| departments.include?(department) }
    employees = EMPLOYEES.select { |_id, department| departments.include?(department) }

    @controller.define_singleton_method(:current_user_group_names) { Set.new }
    @controller.define_singleton_method(:current_user_authorization_console_keys) { granted }
    @controller.define_singleton_method(:set_managed_departments) { @managed_departments = managed }
    @controller.define_singleton_method(:fetch_managed_budget_units) { units.keys.map { |unit| [unit, unit] } }
    @controller.define_singleton_method(:fetch_managed_employees) do
      employees.keys.map { |id| { id: id, name: "Employee #{id}", email: nil } }
    end
    @controller.define_singleton_method(:resolve_department_from_units) do |approver|
      unit = approver.budget_units.to_s.split(',').first
      approver.department_id = AuthorizationConsoleSignIn::UNITS.fetch(unit) if unit.present?
    end
  end
end
