# app/controllers/authorization_console_controller.rb
class AuthorizationConsoleController < ApplicationController
  before_action :require_authorization_manager
  before_action :set_managed_departments
  
  def index
    @department_id = params[:department_id] || @managed_departments.first&.department_id
    
    if @department_id
      @department = Department.find_by(department_id: @department_id)
      @authorized_approvers = AuthorizedApprover
        .where(department_id: @department_id)
        .order(:employee_id, :service_type)
      
      # Group by employee for display
      @approvers_by_employee = @authorized_approvers.group_by(&:employee_id)
    end
  end
  
  def new
    @department_id = params[:department_id]
    @authorized_approver = AuthorizedApprover.new(department_id: @department_id)
    
    @building_options     = fetch_buildings_for_department(@department_id)
    @budget_unit_options  = fetch_budget_units_for_department(@department_id)
    # Get employees from this department for the dropdown
    @department_employees = fetch_department_employees(@department_id)
  end
  
  def create
    @authorized_approver = AuthorizedApprover.new(authorized_approver_params)
    @authorized_approver.authorized_by = session.dig(:user, "employee_id").to_s
    
    if @authorized_approver.save
      redirect_to authorization_console_index_path(department_id: @authorized_approver.department_id),
                  notice: "Approver authorization added successfully."
    else
      @department_id         = @authorized_approver.department_id
      @department_employees  = fetch_department_employees(@department_id)
      @building_options      = fetch_buildings_for_department(@department_id)
      @budget_unit_options   = fetch_budget_units_for_department(@department_id)
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    @authorized_approver   = AuthorizedApprover.find(params[:id])
    @department_id         = @authorized_approver.department_id
    @department_employees  = fetch_department_employees(@department_id)
    @building_options      = fetch_buildings_for_department(@department_id)
    @budget_unit_options   = fetch_budget_units_for_department(@department_id)
  end
  
  def update
    @authorized_approver = AuthorizedApprover.find(params[:id])
    
    if @authorized_approver.update(authorized_approver_params)
      redirect_to authorization_console_index_path(department_id: @authorized_approver.department_id),
                  notice: "Approver authorization updated successfully."
    else
      @department_id         = @authorized_approver.department_id
      @department_employees  = fetch_department_employees(@department_id)
      @building_options      = fetch_buildings_for_department(@department_id)
      @budget_unit_options   = fetch_budget_units_for_department(@department_id)
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
  
  def require_authorization_manager
    employee_id = session.dig(:user, "employee_id").to_s
    
    unless AuthorizationManager.exists?(employee_id: employee_id)
      redirect_to root_path, alert: "You do not have permission to access the Authorization Console."
    end
  end
  
  def set_managed_departments
    employee_id = session.dig(:user, "employee_id").to_s
    @managed_departments = AuthorizationManager
      .where(employee_id: employee_id)
      .map(&:department)  # Remove .includes(:department)
      .compact
  end
  
  def fetch_department_employees(department_id)
    return [] if department_id.blank?
    
    result = ActiveRecord::Base.connection.exec_query(<<-SQL.squish)
      SELECT EmployeeID, First_Name, Last_Name, EE_Email
      FROM [GSABSS].[dbo].[Employees] e
      INNER JOIN [GSABSS].[dbo].[Units] u ON e.Unit = u.unit_id
      WHERE u.department_id = '#{department_id}'
      ORDER BY Last_Name, First_Name
    SQL
    
    result.map do |row|
      {
        id: row["EmployeeID"],
        name: "#{row["First_Name"]} #{row["Last_Name"]} (#{row["EmployeeID"]})",
        email: row["EE_Email"]
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

  def fetch_budget_units_for_department(department_id)
    # Replace with real data source (MSSQL / lookup table / constant)
    %w[4641 4642 4643]
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
