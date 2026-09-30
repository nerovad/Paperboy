# frozen_string_literal: true

# app/controllers/admin/impersonations_controller.rb
module Admin
  class ImpersonationsController < ApplicationController
    before_action -> { require_admin_tab('emulate') }, only: %i[new create]
    before_action :require_active_impersonation, only: :destroy

    def new
      @employees = Employee.order(:last_name, :first_name)
      @contractors = Contractor.order(:last_name, :first_name)
    end

    def create
      # Employees and contractors share one id space (contractor ids start at
      # 1,000,000,000), so one select and Submitter.resolve cover both.
      person = Submitter.resolve(params[:employee_id])
      return redirect_to(new_admin_impersonation_path, alert: 'User not found.') unless person

      # Store who the real admin is. Re-emulating from inside an emulation
      # keeps the original admin rather than the person being emulated.
      unless session[:impersonating]
        session[:real_admin_id] = session[:user_id]
        session[:real_admin_contractor] = session[:contractor]
      end
      session[:impersonating] = true

      # Set session as the impersonated user
      sign_in_as(person)

      redirect_to root_path, notice: "Now emulating #{person.full_name}"
    end

    def destroy
      sign_in_as(real_admin)
      session[:impersonating] = false
      session[:real_admin_id] = nil
      session.delete(:real_admin_contractor)

      redirect_to root_path, notice: 'Stopped emulating'
    end

    private

    def real_admin
      model = session[:real_admin_contractor] ? Contractor : Employee
      model.find(session[:real_admin_id])
    end

    # The same session shape SessionsController and ContractorSessionsController
    # build, so the emulated user is indistinguishable from a real sign-in.
    def sign_in_as(person)
      contractor = person.is_a?(Contractor)
      session[:user_id] = person.employee_id
      if contractor
        session[:contractor] = true
      else
        session.delete(:contractor)
      end
      session[:user] = {
        'email' => person.email,
        'first_name' => person.first_name,
        'last_name' => person.last_name,
        'employee_id' => person.employee_id,
        'phone' => person.work_phone,
        'supervisor_id' => person.supervisor_id,
        'department' => person.department,
        'agency' => person.agency,
        'unit' => person.unit
      }
    end

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
