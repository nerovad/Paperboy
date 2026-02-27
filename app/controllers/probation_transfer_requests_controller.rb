class ProbationTransferRequestsController < ApplicationController
  before_action :set_probation_transfer_request, only: [:show, :edit, :update, :destroy, :pdf, :approve, :deny, :withdraw]

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
      employee_id = session[:user]["employee_id"].to_s

  # Find most recent ACTIVE request within the past year
  @existing_request = ProbationTransferRequest
                        .for_employee(employee_id)
                        .active
                        .where("created_at >= ?", 1.year.ago)
                        .order(created_at: :desc)
                        .first

  # If user chose to proceed anyway (?proceed=1), bypass the gate
  if @existing_request.present? && params[:proceed].blank?
    # used for display
    @expires_on = (@existing_request.expires_at || (@existing_request.created_at + 1.year)).to_date
    return render :existing_request_gate
  end

    @probation_transfer_request = ProbationTransferRequest.new
    prepare_new_transfer_form
  end

 def create
  employee  = session[:user]
  sup_id    = fetch_supervisor_id(employee["employee_id"])
  sup_email = fetch_employee_email(sup_id)

  @probation_transfer_request = ProbationTransferRequest.new(probation_transfer_request_params)
  @probation_transfer_request.status = 0
  @probation_transfer_request.supervisor_id    = sup_id
  @probation_transfer_request.supervisor_email = sup_email

  if (raw = params.dig(:probation_transfer_request, :desired_transfer_destination)).present?
    destinations = Array(raw).reject(&:blank?)
    @probation_transfer_request.desired_transfer_destination = destinations.join("; ")
  end

  if @probation_transfer_request.save
    # only do lifecycle after we have an ID
    ActiveRecord::Base.transaction do
      @probation_transfer_request.ensure_expires!

      ProbationTransferRequest
        .for_employee(@probation_transfer_request.employee_id)
        .where.not(id: @probation_transfer_request.id)
        .active
        .find_each do |older|
          # use update_columns to skip validations/callbacks
          older.update_columns(
            canceled_at: Time.current,
            canceled_reason: "superseded_by_new_request",
            superseded_by_id: @probation_transfer_request.id,
            updated_at: Time.current
          )
        end
    end

    redirect_to form_success_path, allow_other_host: false, status: :see_other
  else
    # See what failed
    Rails.logger.warn("PTR create failed: #{ @probation_transfer_request.errors.full_messages.join('; ') }")
    prepare_new_transfer_form
    render :new, status: :unprocessable_entity
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

  def withdraw
    @probation_transfer_request.cancel!(reason: "withdrawn")
    redirect_to new_probation_transfer_request_path(proceed: 1), notice: "Your previous request was withdrawn. You can submit a new one."
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

  # value coming from the modal <select name="approved_destination">
  selected_dest = params[:approved_destination].to_s.strip.presence

  # If the request listed choices, require one to be selected
  options = @submission.desired_transfer_destination.to_s.split(';').map(&:strip).reject(&:blank?)
  if options.any? && selected_dest.blank?
    return redirect_to inbox_queue_path, alert: "Please choose an approved destination."
  end

  approver_id    = session.dig(:user, "employee_id").to_s
  approver_email = session.dig(:user, "email") || fetch_employee_email(approver_id)

  @submission.update!(
    status: 1,                        # manager_approved
    approved_by: approver_id,
    approved_at: Time.current,
    supervisor_email: @submission.supervisor_email.presence || approver_email,
    approved_destination: selected_dest
  )

  NotifyProbationJob.perform_later(@submission.id)
  redirect_to inbox_queue_path, notice: "Transfer request approved."
end

def deny
  @submission = ProbationTransferRequest.find(params[:id])

  denier_id    = session.dig(:user, "employee_id").to_s
  denier_email = session.dig(:user, "email") || fetch_employee_email(denier_id)
  reason       = params[:denial_reason].to_s.strip

  @submission.update!(
    status: 2,                        # denied
    denied_by: denier_id,
    denied_at: Time.current,
    denial_reason: reason.presence || "No reason provided",
    supervisor_email: @submission.supervisor_email.presence || denier_email
  )

  ProbationMailer.denied(@submission).deliver_later

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
    Employee.find_by(employee_id: employee_id)&.supervisor_id
  end

  def fetch_employee_email(emp_id)
    return nil if emp_id.blank?
    Employee.find_by(employee_id: emp_id)&.email
  end

  def prepare_new_transfer_form
    employee_id = session[:user]["employee_id"]
    @employee = Employee.find_by(employee_id: employee_id)

    unit = Unit.find_by(unit_id: @employee&.unit)
    department = Department.find_by(department_id: unit&.department_id)
    division   = Division.find_by(division_id: department&.division_id)
    agency     = Agency.find_by(agency_id: division&.agency_id)

    @prefill_data = {
      employee_id: @employee&.employee_id,
      name: "#{@employee&.first_name} #{@employee&.last_name}",
      phone: @employee&.work_phone,
      email: @employee&.email,
      agency: agency&.agency_id,
      division: division&.division_id,
      department: department&.department_id,
      unit: unit&.unit_id
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
  Unit.where(department_id: department.department_id)
      .order(:unit_id)
      .map { |u| ["#{u.unit_id} - #{u.long_name}", u.unit_id] }
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
  ["Adult Investigations (AI-I II III)", "Adult Investigations (AI-I II III)"],
  ["East County Field Services (ECFS)", "East County Field Services (ECFS)"],
  ["East County Probation/Post-Release (ECPPR)", "East County Probation/Post-Release (ECPPR)"],
  ["Force Options Training (FOT)", "Force Options Training (FOT)"],
  ["Intensive Supervision Services - Juvenile (ISSJ)", "Intensive Supervision Services - Juvenile (ISSJ)"],
  ["Juvenile Facilities Housing/Operations (JF)", "Juvenile Facilities Housing/Operations (JF)"],
  ["Juvenile Field Services (JFS)", "Juvenile Field Services (JFS)"],
  ["Juvenile Intake/Community Confinement (JINT/CC)", "Juvenile Intake/Community Confinement (JINT/CC)"],
  ["Juvenile Investigations (JINV)", "Juvenile Investigations (JINV)"],
  ["Juvenile Specialty Programs (JSP)", "Juvenile Specialty Programs (JSP)"],
  ["Oxnard Field Services (OFS I/II)", "Oxnard Field Services (OFS I/II)"],
  ["Oxnard Probation/Post-Release (OPPR I/II)", "Oxnard Probation/Post-Release (OPPR I/II)"],
  ["Pretrial Risk Assessment and Monitoring Services (PRAMS)", "Pretrial Risk Assessment and Monitoring Services (PRAMS)"],
  ["Professional Standards Unit (PSU)", "Professional Standards Unit (PSU)"],
  ["Specialized Services Unit (SSU)", "Specialized Services Unit (SSU)"],
  ["Staff Training Unit (STU)", "Staff Training Unit (STU)"],
  ["Ventura Field Services (VFS)", "Ventura Field Services (VFS)"],
  ["Ventura Probation/Post-Release (VPPR)", "Ventura Probation/Post-Release (VPPR)"],
  ["Work Release (WR)", "Work Release (WR)"]
]
  end
end
