class ProbationTransferRequestsController < ApplicationController
  before_action :set_probation_transfer_request, only: [:show, :edit, :update, :destroy, :pdf, :approve, :deny]

  def index
    @probation_transfer_requests = ProbationTransferRequest.where(status: 0, supervisor_id: session[:user]["employee_id"])
  employee = session[:user]

  if employee.present? && employee["employee_id"].present?
    Rails.logger.info "Logged in as employee #{employee["employee_id"]}"

    session[:last_seen_inbox_at] = Time.current

    @pending_submissions = ProbationTransferRequest
                              .where(supervisor_id: employee["employee_id"].to_s)
                              .where(status: 0)
                              .order(created_at: :desc)
  else
    Rails.logger.warn "No logged-in employee found"
    @pending_submissions = []
  end
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
    prepare_new_transfer_form
  end

  def create
    employee = session[:user]
    sup_id   = fetch_supervisor_id(employee["employee_id"])

    @probation_transfer_request = ProbationTransferRequest.new(probation_transfer_request_params)
    @probation_transfer_request.status = 0
    @probation_transfer_request.supervisor_id = sup_id

    if params[:probation_transfer_request][:desired_transfer_destination].present?
      destinations = Array(params[:probation_transfer_request][:desired_transfer_destination]).reject(&:blank?)
      @probation_transfer_request.desired_transfer_destination = destinations.join('; ')
    end

    if @probation_transfer_request.save
      redirect_to form_success_path, allow_other_host: false, status: :see_other
    else
      prepare_new_transfer_form
      render :new
    end
  end

  def edit; end

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

  def pdf
    pdf_data = ProbationTransferPdfGenerator.generate(@probation_transfer_request)

    send_data pdf_data,
              filename: "ProbationTransferRequest_#{@probation_transfer_request.id}.pdf",
              type: "application/pdf",
              disposition: "inline"
  end

def approve
  @submission = ProbationTransferRequest.find(params[:id])
  @submission.update!(status: 1)

  NotifyProbationJob.perform_later(@submission.id)

  redirect_to inbox_queue_path, notice: "Transfer request approved."
end

def deny
  @submission = ProbationTransferRequest.find(params[:id])
  @submission.update!(status: :denied)

  redirect_to inbox_queue_path, alert: "Transfer request denied."
end

  private

  def set_probation_transfer_request
    @probation_transfer_request = ProbationTransferRequest.find(params[:id])
  end

  def probation_transfer_request_params
    params.require(:probation_transfer_request).permit(
      :employee_id, :name, :phone, :email,
      :agency, :division, :department, :unit,
      :work_location, :current_assignment_date,
      :other_transfer_destination,
      desired_transfer_destination: []
    )
  end

  def fetch_supervisor_id(employee_id)
    result = ActiveRecord::Base.connection.exec_query(<<-SQL.squish).first
      SELECT Supervisor_ID
      FROM [GSABSS].[dbo].[Employees]
      WHERE EmployeeID = '#{employee_id}'
    SQL

    result&.fetch("Supervisor_ID", nil)
  end

  def prepare_new_transfer_form
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

    @work_location_options = [
      ["800 S. Victoria", "800 S. Victoria"],
      ["4333 E Vineyard Ave.", "4333 E Vineyard Ave."],
      ["1721 Pacific Ave.", "1721 Pacific Ave."]
    ]
  end
end
