# app/controllers/authorization_console_controller.rb
class AuthorizationConsoleController < ApplicationController
  before_action :require_auth_console
  before_action :set_managed_departments
  
  def index
    @department_id = params[:department_id] || "all"
    managed_dept_ids = @managed_departments.map(&:department_id)

    if @department_id == "all"
      @department = nil
      @authorized_approvers = AuthorizedApprover
        .where(department_id: managed_dept_ids)
        .order(:employee_id, :service_type)
        .to_a
    elsif managed_dept_ids.include?(@department_id)
      @department = Department.find_by(department_id: @department_id)

      # Find all budget-unit IDs that belong to this department
      dept_unit_ids = Unit.where(department_id: @department_id)
                         .pluck(:unit_id).map(&:to_s).to_set

      # Show approvers whose budget units overlap with this department's
      # units, OR whose department_id matches when no units are specified.
      @authorized_approvers = AuthorizedApprover
        .where(department_id: managed_dept_ids)
        .order(:employee_id, :service_type)
        .select { |a|
          if a.budget_units.present?
            (a.budget_units.split(",").map(&:strip).to_set & dept_unit_ids).any?
          else
            a.department_id == @department_id
          end
        }
    end

    @approvers_by_employee = (@authorized_approvers || []).group_by(&:employee_id)
  end
  
  def new
    @department_id = params[:department_id]
    @authorized_approver = AuthorizedApprover.new(department_id: @department_id)

    @building_options     = fetch_buildings_for_department(@department_id)
    @budget_unit_options  = fetch_managed_budget_units
    @department_employees = fetch_managed_employees
  end
  
  def create
    @authorized_approver = AuthorizedApprover.new(authorized_approver_params)
    @authorized_approver.authorized_by = session.dig(:user, "employee_id").to_s
    resolve_department_from_units(@authorized_approver)

    if @authorized_approver.save
      redirect_to authorization_console_index_path(department_id: @authorized_approver.department_id),
                  notice: "Approver authorization added successfully."
    else
      @department_id         = @authorized_approver.department_id
      @department_employees  = fetch_managed_employees
      @building_options      = fetch_buildings_for_department(@department_id)
      @budget_unit_options   = fetch_managed_budget_units
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    @authorized_approver   = AuthorizedApprover.find(params[:id])
    @department_id         = @authorized_approver.department_id
    @department_employees  = fetch_managed_employees
    @building_options      = fetch_buildings_for_department(@department_id)
    @budget_unit_options   = fetch_managed_budget_units
  end
  
  def update
    @authorized_approver = AuthorizedApprover.find(params[:id])
    @authorized_approver.assign_attributes(authorized_approver_params)
    resolve_department_from_units(@authorized_approver)

    if @authorized_approver.save
      redirect_to authorization_console_index_path(department_id: @authorized_approver.department_id),
                  notice: "Approver authorization updated successfully."
    else
      @department_id         = @authorized_approver.department_id
      @department_employees  = fetch_managed_employees
      @building_options      = fetch_buildings_for_department(@department_id)
      @budget_unit_options   = fetch_managed_budget_units
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @authorized_approver = AuthorizedApprover.find(params[:id])
    department_id = @authorized_approver.department_id
    @authorized_approver.destroy
    
    redirect_to authorization_console_index_path(department_id: department_id),
                notice: "Approver authorization removed."
  end
  
  def destroy_all_for_employee
    employee_id   = params[:employee_id]
    department_id = params[:department_id]
    
    AuthorizedApprover.where(employee_id: employee_id, department_id: department_id).destroy_all
    
    redirect_to authorization_console_index_path(department_id: department_id),
                notice: "All authorizations removed for employee #{employee_id}."
  end
  
  private
  
  def set_managed_departments
    if auth_console_admin?
      gsa = Agency.find_by(long_name: "General Services Agency")
      division_ids = gsa ? Division.where(agency_id: gsa.agency_id).pluck(:division_id) : []
      @managed_departments = Department.where(division_id: division_ids).order(:department_id).to_a
    else
      dept_id = current_user_org_chain[:department_id]
      dept = dept_id ? Department.find_by(department_id: dept_id) : nil
      @managed_departments = [dept].compact
    end
  end
  
  def fetch_managed_employees
    dept_ids = @managed_departments.map(&:department_id)
    return [] if dept_ids.empty?

    unit_ids = Unit.where(department_id: dept_ids).pluck(:unit_id)
    employees = Employee.where(unit: unit_ids).order(:last_name, :first_name)

    employees.map do |e|
      {
        id: e.employee_id,
        name: "#{e.first_name} #{e.last_name} (#{e.employee_id})",
        email: e.email
      }
    end
  end
  
  def fetch_buildings_for_department(department_id)
    # Replace this with your real logic / query
    # e.g. Building.where(department_id:).order(:name).pluck(:name)
    [
      "Hall of Administration",
      "Government Center - A",
      "Government Center - B"
    ]
  end

  def fetch_managed_budget_units
    dept_ids = @managed_departments.map(&:department_id)
    return [] if dept_ids.empty?

    dept_names = @managed_departments.index_by(&:department_id)
    Unit.where(department_id: dept_ids).order(:unit_id).map do |u|
      label = "#{u.unit_id} - #{dept_names[u.department_id]&.long_name}"
      [label, u.unit_id.to_s]
    end
  end

  # Derive department_id from the first selected budget unit's actual department.
  # Falls back to the existing department_id when no budget units are selected.
  def resolve_department_from_units(approver)
    return if approver.budget_units.blank?

    first_unit_id = approver.budget_units.split(",").first&.strip
    return if first_unit_id.blank?

    unit = Unit.find_by(unit_id: first_unit_id)
    approver.department_id = unit.department_id if unit&.department_id.present?
  end

  def authorized_approver_params
    raw = params.require(:authorized_approver).permit(
      :employee_id,
      :department_id,
      :service_type,
      :key_type,
      :span,
      locations: [],
      budget_units: []
    )

    # Normalize multi-select arrays into comma-separated strings
    raw[:locations]     = Array(raw[:locations]).reject(&:blank?).join(",")
    raw[:budget_units]  = Array(raw[:budget_units]).reject(&:blank?).join(",")

    raw
  end
end
