# app/controllers/admin/impersonations_controller.rb
class Admin::ImpersonationsController < ApplicationController
  before_action :require_super_admin

  def new
    @employees = Employee.order(:last_name, :first_name)
  end

  def create
    employee = Employee.find(params[:employee_id])

    # Store who the real admin is
    session[:real_admin_id] = session[:user_id]
    session[:impersonating] = true

    # Set session as the impersonated user
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

    redirect_to root_path, notice: "Now emulating #{employee.first_name} #{employee.last_name}"
  end

  def destroy
    real_admin = Employee.find(session[:real_admin_id])

    session[:user_id] = real_admin.employee_id
    session[:user] = {
      "email" => real_admin.email,
      "first_name" => real_admin.first_name,
      "last_name" => real_admin.last_name,
      "employee_id" => real_admin.employee_id,
      "phone" => real_admin.work_phone,
      "supervisor_id" => real_admin.supervisor_id,
      "department" => real_admin.department,
      "agency" => real_admin.agency,
      "unit" => real_admin.unit
    }
    session[:impersonating] = false
    session[:real_admin_id] = nil

    redirect_to root_path, notice: "Stopped emulating"
  end

  private

  def require_super_admin
    unless session[:user_id].present?
      redirect_to root_path, alert: "Access denied"
    end
  end
end
