class ProbationTransferRequestsController < ApplicationController
  before_action :set_probation_transfer_request, only: [:show, :edit, :update, :destroy]

  def index
    @probation_transfer_requests = ProbationTransferRequest.all
  end

  def show
    respond_to do |format|
      format.html
      format.pdf do
        render pdf: "transfer_request_#{@probation_transfer_request.id}",
               template: "probation_transfer_requests/pdf",
               locals: { request: @probation_transfer_request },
               formats: [:html]
      end
    end
  end

  def new
  @probation_transfer_request = ProbationTransferRequest.new

  employee_id = session[:user]["employee_id"]
  @employee = Employee.find_by(EmployeeID: employee_id)

  unit_code = @employee&.[]("Unit")
  unit = Unit.find_by(unit_id: unit_code)

  department = Department.find_by(department_id: unit&.[]("department_id"))
  division   = Division.find_by(division_id: department&.[]("division_id"))
  agency     = Agency.find_by(agency_id: division&.[]("agency_id"))

  @prefill_data = {
    employee_id: @employee&.[]("EmployeeID"),
    name: "#{@employee&.[]("First_Name")} #{@employee&.[]("Last_Name")}",
    phone: @employee&.[]("Work_Phone"),
    email: @employee&.[]("EE_Email"),
    agency: agency&.agency_id,
    division: division&.division_id,
    department: department&.department_id,
    unit: unit ? "#{unit.unit_id} - #{unit.long_name}" : nil
  }

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

  @form_logo = "/assets/images/default-logo.svg"

  @form_pages = [
    {
      title: "Employee Info",
      fields: [
        { name: "employee_id", label: "Employee ID", type: "text", required: true },
        { name: "name", label: "Name", type: "text", required: true },
        { name: "email", label: "Email", type: "text", required: true },
        { name: "phone", label: "Phone", type: "text", required: true }
      ]
    },
    {
      title: "Agency Info"
    },
    {
      title: "Transfer Request Details",
      fields: [
        { name: "work_location", label: "Work Location", type: "text", required: true },
        { name: "current_assignment_date", label: "Current Assignment Date", type: "text", required: true },
        { name: "desired_transfer_destination", label: "Desired Transfer Destination", type: "multi-select", options: ["East County", "West County", "Downtown", "Remote", "Other"] }
      ]
    }
  ]
end

  def edit
  end

  def create
    raw_params = probation_transfer_request_params

    @probation_transfer_request = ProbationTransferRequest.new(raw_params)
    @probation_transfer_request.status = 0

    if @probation_transfer_request.save
      TransferMailer.notify(@probation_transfer_request).deliver_later
      redirect_to probation_transfer_requests_path, notice: "Transfer request submitted!"
    else
      render :new
    end
  end

  def update
    if @probation_transfer_request.update(probation_transfer_request_params)
      redirect_to @probation_transfer_request, notice: "Transfer request updated."
    else
      render :edit
    end
  end

  def destroy
    @probation_transfer_request.destroy
    redirect_to probation_transfer_requests_url, notice: "Transfer request deleted."
  end

  private

  def set_probation_transfer_request
    @probation_transfer_request = ProbationTransferRequest.find(params[:id])
  end

  def probation_transfer_request_params
    params.require(:probation_transfer_request).permit(
      :employee_id,
      :name,
      :email,
      :phone,
      :agency,
      :division,
      :department,
      :unit,
      :work_location,
      :current_assignment_date,
      :desired_transfer_destination,
      :status
    )
  end
end
