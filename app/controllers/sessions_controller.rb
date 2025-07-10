class SessionsController < ApplicationController
  def create
    login = params[:login]

    employee = ActiveRecord::Base.connection.exec_query(<<-SQL).first
      SELECT TOP 1 EmployeeID, FirstName, LastName, Email
      FROM [GSABSS].[dbo].[TC60_Employees]
      WHERE EmployeeID = '#{login}' OR Email = '#{login}'
    SQL

    if employee
      session[:user] = {
        "employee_id" => employee["EmployeeID"],
        "first_name"  => employee["FirstName"],
        "last_name"   => employee["LastName"],
        "email"       => employee["Email"]
      }
      render json: { success: true }
    else
      render json: { success: false }, status: :unauthorized
    end
  end

  def destroy
    session[:user] = nil
    reset_session
    redirect_to root_path, notice: "Logged out successfully."
  end
end
