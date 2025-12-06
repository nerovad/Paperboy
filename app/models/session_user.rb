# app/models/session_user.rb
class SessionUser
  include ActiveModel::Model
  attr_accessor :employee_id, :email, :first_name, :last_name
  
  def self.authenticate(emp_id_or_email)
    conn = ActiveRecord::Base.connection.raw_connection
    # SECURITY WARNING: This has SQL injection vulnerability - should use parameterized queries
    result = conn.execute(<<~SQL)
      SELECT TOP 1 EmployeeID, First_Name, Last_Name, EE_Email
      FROM [GSABSS].[dbo].[Employees]
      WHERE EmployeeID = '#{emp_id_or_email}' OR EE_Email = '#{emp_id_or_email}'
    SQL
    row = result.each(as: :hash).first
    return nil unless row
    new(
      employee_id: row["EmployeeID"],
      first_name: row["First_Name"],
      last_name: row["Last_Name"],
      email: row["EE_Email"]
    )
  rescue => e
    Rails.logger.error("Login error: #{e.message}")
    nil
  end
  
  # Get the actual Employee record for this session user
  def employee
    @employee ||= Employee.find_by(EmployeeID: employee_id)
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
