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
    employee = Employee.where("email ILIKE ?", "#{username}@%").first

    Rails.logger.info "Employee found: #{employee.inspect}"

    if employee.nil?
      Rails.logger.error "NO EMPLOYEE FOUND for username: #{username}"
      redirect_to root_path, alert: "Employee not found. Contact IT."
      return
    end

    # Store employee data in session
    session[:user_id] = employee.employee_id
    session[:user] = {
      "email" => employee.email,
      "first_name" => employee.first_name,
      "last_name" => employee.last_name,
      "employee_id" => employee.employee_id,
      "phone" => employee.work_phone,
      "supervisor_id" => employee.supervisor_id,
      "department" => employee.department,
      "agency" => employee.agency,
      "unit" => employee.unit
    }

    Rails.logger.info "Session set for employee_id: #{employee.employee_id}"
    Rails.logger.info "Redirecting to root_path"

    redirect_to root_path
  end

  # OLD: Keep this for admin impersonation/testing
  def create_legacy
    employee = Employee.find_by(employee_id: params[:id])

    if employee
      session[:user_id] = employee.employee_id
      session[:user] = {
        "email" => employee.email,
        "first_name" => employee.first_name,
        "last_name" => employee.last_name,
        "employee_id" => employee.employee_id,
        "phone" => employee.work_phone,
        "supervisor_id" => employee.supervisor_id,
        "department" => employee.department,
        "agency" => employee.agency,
        "unit" => employee.unit
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
