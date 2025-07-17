class SessionsController < ApplicationController
  def create
    login = params[:login]

    employee = ActiveRecord::Base.connection.exec_query(<<-SQL).first
      SELECT TOP 1 EmployeeID, First_Name, Last_Name, EE_Email
      FROM [GSABSS].[dbo].[Employees]
      WHERE EmployeeID = '#{login}' OR EE_Email = '#{login}'
    SQL

    if employee
      session[:user] = {
        "employee_id" => employee["EmployeeID"],
        "first_name"  => employee["First_Name"],
        "last_name"   => employee["Last_Name"],
        "email"       => employee["EE_Email"]
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
