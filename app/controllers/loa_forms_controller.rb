class LoaFormsController < ApplicationController
def new
  @loa_form = LoaForm.new

  # Prefill basics (same helper you added)
  employee_id = session[:user]&.dig("employee_id")
  @prefill_data = build_prefill_data(employee_id)

  # Resolve the org chain based on the employee’s Unit -> Dept -> Division -> Agency
  employee   = Employee.find_by(EmployeeID: employee_id)
  unit_code  = employee&.[]("Unit")
  unit       = Unit.find_by(unit_id: unit_code)
  department = Department.find_by(department_id: unit&.department_id)
  division   = Division.find_by(division_id: department&.division_id)
  agency     = Agency.find_by(agency_id: division&.agency_id)

  # Build dropdown options (so the first render is populated)
  @agency_options = Agency.all.map { |a| [a.long_name, a.agency_id] }

  @division_options = if agency
    Division.where(agency_id: agency.agency_id).map { |d| [d.long_name, d.division_id] }
  else
    []
  end

  @department_options = if division
    Department.where(division_id: division.division_id).map { |d| [d.long_name, d.department_id] }
  else
    []
  end

  @unit_options = if department
    Unit.where(department_id: department.department_id).map { |u| ["#{u.unit_id} - #{u.short_name}", u.unit_id] }
  else
    []
  end

  # Ensure the selects have the right *IDs* selected on first render
  @prefill_data[:agency]     = agency&.agency_id
  @prefill_data[:division]   = division&.division_id
  @prefill_data[:department] = department&.department_id
  @prefill_data[:unit]       = unit&.unit_id

  @form_pages = [
    { title: "Employee Info" },
    { title: "Leave Details" }
  ]

  @form_logo = "/assets/images/default-logo.svg"
end

  def create
    @event = Event.create(
      event_type: "loa",
      employee_id: params[:loa_form][:employee_id],
      event_date: params[:loa_form][:start_date]
    )

    @loa_form = LoaForm.new(loa_form_params.merge(event_id: @event.id))

    if @loa_form.save
      redirect_to root_path, notice: "Leave of Absence submitted!"
    else
      render :new
    end
  end

  private

  def loa_form_params
    params.require(:loa_form).permit(
      :employee_id, :start_date, :end_date, :reason, :approved
    )
  end
end
