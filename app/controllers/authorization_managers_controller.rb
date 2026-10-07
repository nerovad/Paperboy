# frozen_string_literal: true

# app/controllers/authorization_managers_controller.rb
#
# Who manages which departments in the parking, badges and keys console.
#
# A department's managers appoint and remove each other here, so keeping the
# list current is not an ACL change. An admin (auth_console_admin?) does the
# same for any department, and is the only one who can name someone from
# outside the departments being managed.
class AuthorizationManagersController < ApplicationController
  include AuthorizationConsoleDepartments

  before_action :require_auth_console
  before_action :set_managed_departments
  before_action :require_manager_admin

  def index
    @departments = manager_admin_departments
    @managers_by_department = AuthorizationManager.active
                                                  .where(department_id: admin_department_ids)
                                                  .order(:created_at)
                                                  .group_by { |manager| manager.department_id.to_s }
    @employee_names = candidate_employees.to_h { |employee| [employee[:id].to_s, employee[:name]] }
    @candidates = candidate_employees
  end

  def create
    manager = AuthorizationManager.new(employee_id: params[:employee_id].to_s,
                                       department_id: params[:department_id].to_s,
                                       assigned_by: current_employee_id)
    return refuse('That employee or department is outside the departments you manage.') unless assignable?(manager)

    if manager.save
      redirect_to authorization_managers_path, notice: 'Manager added.'
    else
      refuse(manager.errors.full_messages.to_sentence)
    end
  end

  def destroy
    manager = AuthorizationManager.active.find_by(id: params[:id], department_id: admin_department_ids)
    return refuse('Manager not found.') if manager.nil?

    # A department's own managers may hand it on, never abandon it. Only an
    # admin, who can still reach the department afterwards, may empty the list.
    stranding = manager.last_for_department? && !auth_console_admin?
    return refuse('A department needs at least one manager. Add another before removing this one.') if stranding

    manager.remove!(removed_by: current_employee_id)
    redirect_to authorization_managers_path, notice: 'Manager removed.'
  end

  private

  def require_manager_admin
    return if manager_admin_departments.any?

    redirect_to authorization_console_index_path, alert: 'Access denied. You do not manage any departments.'
  end

  def admin_department_ids
    @admin_department_ids ||= manager_admin_departments.map { |department| department.department_id.to_s }
  end

  # Who may be named a manager: anyone working in a department this user
  # manages the list for. For an admin that is every department.
  def candidate_employees
    @candidate_employees ||= employees_in_departments(admin_department_ids)
  end

  def assignable?(manager)
    admin_department_ids.include?(manager.department_id) &&
      candidate_employees.any? { |employee| employee[:id].to_s == manager.employee_id }
  end

  def refuse(message)
    redirect_to authorization_managers_path, alert: message
  end
end
