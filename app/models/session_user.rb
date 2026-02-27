# app/models/session_user.rb
class SessionUser
  include ActiveModel::Model
  attr_accessor :employee_id, :email, :first_name, :last_name

  def self.authenticate(emp_id_or_email)
    employee = Employee.where(employee_id: emp_id_or_email)
                       .or(Employee.where(email: emp_id_or_email))
                       .first
    return nil unless employee

    new(
      employee_id: employee.employee_id,
      first_name: employee.first_name,
      last_name: employee.last_name,
      email: employee.email
    )
  rescue => e
    Rails.logger.error("Login error: #{e.message}")
    nil
  end

  # Get the actual Employee record for this session user
  def employee
    @employee ||= Employee.find_by(employee_id: employee_id)
  end

  # Check if user belongs to a specific group
  def in_group?(group_name)
    return false unless employee
    employee.in_group?(group_name)
  end

  # Check if user belongs to any of the specified groups
  def in_any_group?(*group_names)
    return false unless employee
    employee.in_any_group?(*group_names)
  end
end
