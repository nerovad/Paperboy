class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  helper_method :current_user

  def current_user
    user_data = session[:user]
    return nil unless user_data&.dig("employee_id") && user_data&.dig("email")

    @current_user ||= SessionUser.new(
      employee_id: user_data["employee_id"],
      email: user_data["email"],
      first_name: user_data["first_name"],
      last_name: user_data["last_name"]
    )
  end

  def build_prefill_data(employee_id)
    employee = Employee.find_by(EmployeeID: employee_id)
    return {} unless employee

    unit_code = employee["Unit"]
    unit = Unit.find_by(unit_id: unit_code)
    department = Department.find_by(department_id: unit&.department_id)
    division   = Division.find_by(division_id: department&.division_id)
    agency     = Agency.find_by(agency_id: division&.agency_id)

    {
      employee_id: employee["EmployeeID"],
      name: "#{employee["First_Name"]} #{employee["Last_Name"]}",
      phone: employee["Work_Phone"],
      email: employee["EE_Email"],
      agency: agency&.agency_id,
      division: division&.division_id,
      department: department&.department_id,
      unit: unit ? "#{unit.unit_id} - #{unit.long_name}" : nil
    }
  end
end
