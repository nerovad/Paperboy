# frozen_string_literal: true

# app/controllers/admin/impersonations_controller.rb
module Admin
  class ImpersonationsController < ApplicationController
    before_action -> { require_admin_tab('emulate') }, only: %i[new create]
    before_action :require_active_impersonation, only: :destroy

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
        'email' => employee.email,
        'first_name' => employee.first_name,
        'last_name' => employee.last_name,
        'employee_id' => employee.employee_id,
        'phone' => employee.work_phone,
        'supervisor_id' => employee.supervisor_id,
        'department' => employee.department,
        'agency' => employee.agency,
        'unit' => employee.unit
      }

      redirect_to root_path, notice: "Now emulating #{employee.first_name} #{employee.last_name}"
    end

    def destroy
      real_admin = Employee.find(session[:real_admin_id])

      session[:user_id] = real_admin.employee_id
      session[:user] = {
        'email' => real_admin.email,
        'first_name' => real_admin.first_name,
        'last_name' => real_admin.last_name,
        'employee_id' => real_admin.employee_id,
        'phone' => real_admin.work_phone,
        'supervisor_id' => real_admin.supervisor_id,
        'department' => real_admin.department,
        'agency' => real_admin.agency,
        'unit' => real_admin.unit
      }
      session[:impersonating] = false
      session[:real_admin_id] = nil

      redirect_to root_path, notice: 'Stopped emulating'
    end

    private

    # Ending an emulation must stay reachable while the *emulated* user's
    # permissions are the ones in effect — gating it on the 'emulate' grant
    # would strand an admin who is emulating someone without that grant. A
    # real_admin_id in the session is proof this session began as a legitimate
    # emulation, so that alone is the gate here.
    def require_active_impersonation
      return if session[:impersonating] && session[:real_admin_id].present?

      redirect_to root_path, alert: 'Not currently emulating.'
    end
  end
end
