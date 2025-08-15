# app/controllers/loa_forms_controller.rb
class LoaFormsController < ApplicationController
def new
  @loa_form = LoaForm.new
  employee_id = session[:user]["employee_id"]
  @employee = Employee.find_by(EmployeeID: employee_id)

  @loa_form.employee_id = employee_id

  unit_code   = @employee&.[]("Unit")
  unit        = Unit.find_by(unit_id: unit_code)
  department  = Department.find_by(department_id: unit&.[]("department_id"))
  division    = Division.find_by(division_id: department&.[]("division_id"))
  agency      = Agency.find_by(agency_id: division&.[]("agency_id"))

  @prefill_data = {
    employee_id: employee_id,
    name: "#{@employee["First_Name"]} #{@employee["Last_Name"]}".strip,
    email: @employee["EE_Email"],
    agency: agency&.agency_id,
    division: division&.division_id,
    department: department&.department_id,
    unit: unit&.unit_id
  }

  # Dropdown options
  @agency_options = Agency.order(:long_name).pluck(:long_name, :agency_id)
  @division_options = Division.where(agency_id: @prefill_data[:agency])
                              .order(:long_name).pluck(:long_name, :division_id)

  @department_options = Department.where(division_id: @prefill_data[:division])
                                  .order(:long_name).pluck(:long_name, :department_id)

  @unit_options = Unit.where(department_id: @prefill_data[:department])
                      .order(:long_name).pluck(:long_name, :unit_id)
end

  def create
    @loa_form = LoaForm.new(loa_form_params)
    if @loa_form.save
      redirect_to form_success_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def loa_form_params
  params.require(:loa_form).permit(
    :employee_id,
    :employee_name,
    :work_email,
    :agency, :division, :department, :unit,
    :last_date_worked, :start_date, :end_date, :extension,
    :reason, :pay_status, :leave_type,
    :supervisor_name, :supervisor_phone, :supervisor_email,
    :disability_benefits, :waive_benefits, :notes,
    :agreement_initials, :confirmed_via_email
  )
end
end
