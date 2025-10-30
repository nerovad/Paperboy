# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  
  # NEW: OAuth/Entra ID login
  def create_oauth
    auth = request.env['omniauth.auth']
    
    Rails.logger.info "=== OAuth Callback ==="
    Rails.logger.info "Email from Entra: #{auth.info.email}"
    
    # Extract just the username part (before @)
    username = auth.info.email.split('@').first.downcase
    
    Rails.logger.info "Looking up username: #{username}"
    
    # Case-insensitive search for any email starting with this username
    employee = Employee.where("LOWER(EE_Email) LIKE ?", "#{username}@%").first
    
    Rails.logger.info "Employee found: #{employee.inspect}"
    
    if employee.nil?
      Rails.logger.error "NO EMPLOYEE FOUND for username: #{username}"
      redirect_to root_path, alert: "Employee not found. Contact IT."
      return
    end
    
    # Store employee data in session
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
    
    Rails.logger.info "Session set for EmployeeID: #{employee.EmployeeID}"
    Rails.logger.info "Redirecting to root_path"

    redirect_to root_path
  end
  
  # OLD: Keep this for admin impersonation/testing
  def create_legacy
    employee = Employee.find_by(EmployeeID: params[:id])
    
    if employee
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
      redirect_to root_path
    else
      redirect_to root_path, alert: "User not found"
    end
  end
  
  def failure
    redirect_to root_path, alert: "Authentication failed: #{params[:message]}"
  end
  
  def destroy
    session[:user_id] = nil
    session[:user] = nil
    redirect_to root_path
  end
end
