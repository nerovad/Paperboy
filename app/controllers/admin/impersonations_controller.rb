# app/controllers/admin/impersonations_controller.rb
class Admin::ImpersonationsController < ApplicationController
  before_action :require_super_admin
  
  def new
    @employees = Employee.order(:Last_Name, :First_Name)
  end
  
  def create
    employee = Employee.find(params[:employee_id])
    
    # Store who the real admin is
    session[:real_admin_id] = session[:user_id]
    session[:impersonating] = true
    
    # Set session as the impersonated user
    session[:user_id] = employee.EmployeeID
    session[:user] = {
      "email" => employee.EE_Email,
      "first_name" => employee.First_Name,
      "last_name" => employee.Last_Name,
      "employee_id" => employee.EmployeeID,
      "phone" => employee.Work_Phone,
      "supervisor_id" => employee.Supervisor_ID,
      "department" => employee.Department,
      "agency" => employee.Agency,
      "unit" => employee.Unit
    }
    
    redirect_to root_path, notice: "Now emulating #{employee.First_Name} #{employee.Last_Name}"
  end
  
  def destroy
    real_admin = Employee.find(session[:real_admin_id])
    
    session[:user_id] = real_admin.EmployeeID
    session[:user] = {
      "email" => real_admin.EE_Email,
      "first_name" => real_admin.First_Name,
      "last_name" => real_admin.Last_Name,
      "employee_id" => real_admin.EmployeeID,
      "phone" => real_admin.Work_Phone,
      "supervisor_id" => real_admin.Supervisor_ID,
      "department" => real_admin.Department,
      "agency" => real_admin.Agency,
      "unit" => real_admin.Unit
    }
    session[:impersonating] = false
    session[:real_admin_id] = nil
    
    redirect_to root_path, notice: "Stopped emulating"
  end
  
  private
  
  def require_super_admin
    # Add your super admin check here
    # For now, just check if you're logged in
    unless session[:user_id].present?
      redirect_to root_path, alert: "Access denied"
    end
    
    # TODO: Add real super admin check
    # unless session[:user]["employee_id"].in?([136626, other_admin_ids])
    #   redirect_to root_path, alert: "Access denied"
    # end
  end
end
