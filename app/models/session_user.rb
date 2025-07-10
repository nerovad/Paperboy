class SessionUser
  include ActiveModel::Model
  attr_accessor :employee_id, :email, :first_name, :last_name

  def self.authenticate(emp_id_or_email)
    conn = ActiveRecord::Base.connection.raw_connection
    result = conn.execute(<<~SQL)
      SELECT TOP 1 EmployeeID, FirstName, LastName, Email
      FROM [GSABSS].[dbo].[TC60_Employees]
      WHERE EmployeeID = '#{emp_id_or_email}' OR Email = '#{emp_id_or_email}'
    SQL

    row = result.each(as: :hash).first
    return nil unless row

    new(
      employee_id: row["EmployeeID"],
      first_name: row["FirstName"],
      last_name: row["LastName"],
      email: row["Email"]
    )
  rescue => e
    Rails.logger.error("Login error: #{e.message}")
    nil
  end
end
