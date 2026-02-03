# app/controllers/parking_lot_submissions_controller.rb
class ParkingLotSubmissionsController < ApplicationController
  before_action :set_parking_lot_submission, only: [:show, :pdf, :approve, :deny]

def new
  @parking_lot_submission = ParkingLotSubmission.new
  @parking_lot_submission.parking_lot_vehicles.build

  # Safely read session
  employee_id = session.dig(:user, "employee_id").to_s
  @employee   = employee_id.present? ? Employee.find_by(EmployeeID: employee_id) : nil

  unless @employee
    redirect_to login_path, alert: "Please sign in to start a submission." and return

    @agency_options     = Agency.order(:long_name).pluck(:long_name, :agency_id)
    @division_options   = []
    @department_options = []
    @unit_options       = []
    return
  end

  # MB3 flag
  @is_mb3 = @employee["Union_Code"].to_s.upcase == "MB3"

  # Org lookups (guard each step)
  unit        = Unit.find_by(unit_id: @employee["Unit"])
  department  = unit ? Department.find_by(department_id: unit["department_id"]) : nil
  division    = department ? Division.find_by(division_id: department["division_id"]) : nil
  agency      = division ? Agency.find_by(agency_id: division["agency_id"]) : nil

  # Prefill with IDs (unit = ID only)
  @prefill_data = {
    employee_id: @employee["EmployeeID"],
    name:        [@employee["First_Name"], @employee["Last_Name"]].compact.join(" "),
    phone:       @employee["Work_Phone"],
    email:       @employee["EE_Email"],
    agency:      agency&.agency_id,
    division:    division&.division_id,
    department:  department&.department_id,
    unit:        unit&.unit_id
  }

  # Parking lots
  base_lots             = %w[A\ Lot B\ Lot C\ Lot D\ Lot Employee\ Lot Visitor\ Lot]
  @allowed_parking_lots = @is_mb3 ? (base_lots + ["R Lot"]) : base_lots

  # Dropdowns
  @agency_options = Agency.order(:long_name).pluck(:long_name, :agency_id)

  @division_options = if agency
    Division.where(agency_id: agency.agency_id).order(:long_name).pluck(:long_name, :division_id)
  else
    []
  end

  @department_options = if division
    Department.where(division_id: division.division_id).order(:long_name).pluck(:long_name, :department_id)
  else
    []
  end

  # 👇 Unit label = "unit_id - long_name", value = unit_id (as requested)
  @unit_options = if department
    Unit.where(department_id: department.department_id)
        .order(:unit_id)
        .map { |u| ["#{u.unit_id} - #{u.long_name}", u.unit_id] }
  else
    []
  end
end

def create
  employee      = session[:user]
  employee_id   = employee["employee_id"].to_s
  
  # Check Union Code from DB (trust server-side)
  union_code = ActiveRecord::Base.connection.exec_query(<<-SQL.squish).first&.fetch("Union_Code", nil).to_s.upcase
    SELECT Union_Code
    FROM [GSABSS].[dbo].[Employees]
    WHERE EmployeeID = '#{employee_id}'
  SQL
  is_mb3 = (union_code == "MB3")
  
  # Get employee's department for authorized approver lookup
  emp_record = Employee.find_by(EmployeeID: employee_id)
  unit = Unit.find_by(unit_id: emp_record["Unit"])
  department = unit ? Department.find_by(department_id: unit["department_id"]) : nil

  # Build the submission early so we can access the submitted unit
  @parking_lot_submission = ParkingLotSubmission.new(parking_lot_submission_params)
  @parking_lot_submission.employee_id = employee_id
  submitted_unit = @parking_lot_submission.unit

  # Find authorized approver for parking permits matching the submitter's budget unit
  authorized_approvers = if department && submitted_unit.present?
    AuthorizedApprover.approver_for_unit(
      department_id: department.department_id,
      service_type: 'P',
      unit_id: submitted_unit
    )
  else
    []
  end

  # MB3 employees skip approval routing entirely
  unless is_mb3
    if authorized_approvers.empty?
      @parking_lot_submission.errors.add(:base, "No authorized approver found for Parking Permits in your budget unit. Please contact your department's authorization manager.")
      @is_mb3 = false
      base_lots = ["A Lot", "B Lot", "C Lot", "D Lot", "Employee Lot", "Visitor Lot"]
      @allowed_parking_lots = base_lots
      reload_form_options(emp_record)
      render :new, status: :unprocessable_entity and return
    end
  end

  if is_mb3
    # Auto-approve: no manager routing
    @parking_lot_submission.status        = 1 # manager_approved
    @parking_lot_submission.supervisor_id = nil
    @parking_lot_submission.approved_by   = employee_id # or "SYSTEM"
    @parking_lot_submission.approved_at   = Time.current
  else
    # Normal path: submitted and routed to authorized approver for their budget unit
    @parking_lot_submission.status           = 0 # submitted
    @parking_lot_submission.supervisor_id    = authorized_approvers.first
    @parking_lot_submission.supervisor_email = fetch_employee_email(authorized_approvers.first)
  end

  if @parking_lot_submission.save
    if is_mb3
      NotifySecurityJob.perform_later(@parking_lot_submission.id)
    end
    redirect_to form_success_path, allow_other_host: false, status: :see_other
  else
    @is_mb3 = is_mb3
    base_lots = ["A Lot", "B Lot", "C Lot", "D Lot", "Employee Lot", "Visitor Lot"]
    @allowed_parking_lots = is_mb3 ? (base_lots + ["R Lot"]) : base_lots
    reload_form_options(emp_record)
    render :new, status: :unprocessable_entity
  end
end

  # READ-ONLY SHOW (uses your shared partial in the view)
  def show; end

  def pdf
    # @parking_lot_submission is already set by before_action
    pdf_data = ParkingLotPdfGenerator.generate(@parking_lot_submission)

    send_data pdf_data,
              filename: "ParkingLotSubmission_#{@parking_lot_submission.id}.pdf",
              type: "application/pdf",
              disposition: "inline"
  end

def approve
  @submission = ParkingLotSubmission.find(params[:id])
  approver_id = session.dig(:user, "employee_id").to_s

  if @submission.submitted?
    # AUTHORIZED APPROVER APPROVAL - always routes to Sean Payne for final approval
    sean_payne_id = "104236"
    sean_payne_email = "Sean.Payne@ventura.org"

    @submission.update!(
      status: 1,  # pending_delegated_approval
      approved_by: approver_id,
      approved_at: Time.current,
      delegated_approver_id: sean_payne_id,
      delegated_approver_email: sean_payne_email
    )

    # Send notification to Sean Payne
    SecurityMailer.notify_delegated_approver(@submission).deliver_later

    redirect_to inbox_queue_path, notice: "Request approved and sent to Sean Payne for final approval."

  elsif @submission.pending_delegated_approval?
    # SEAN PAYNE FINAL APPROVAL - sends to Security after approval
    @submission.update!(
      status: 3,  # approved
      delegated_approved_by: approver_id,
      delegated_approved_at: Time.current
    )

    # Send to Security
    NotifySecurityJob.perform_later(@submission.id)

    @submission.update!(status: 4)  # sent_to_security

    redirect_to inbox_queue_path, notice: "Request approved and sent to Security."
  else
    redirect_to inbox_queue_path, alert: "Invalid approval state."
  end
end

def deny
  @submission = ParkingLotSubmission.find(params[:id])

  denier_id    = session.dig(:user, "employee_id").to_s
  reason       = params[:denial_reason].to_s.strip

  @submission.update!(
    status: 2,                        # use your correct denied code
    denied_by: denier_id,
    denied_at: Time.current,
    denial_reason: reason.presence || "No reason provided"
  )

  SecurityMailer.denied(@submission).deliver_later

  redirect_to inbox_queue_path, alert: "Parking request denied."
end

  def index
    # If you intend to always redirect to inbox, do it and return to avoid extra work below
    redirect_to inbox_queue_path and return

    employee = session[:user]

    if employee.present? && employee["employee_id"].present?
      Rails.logger.info "Logged in as employee #{employee["employee_id"]}"
      session[:last_seen_inbox_at] = Time.current

      @pending_submissions = ParkingLotSubmission
                               .where(supervisor_id: employee["employee_id"].to_s)
                               .where(status: 0)
                               .order(created_at: :desc)
    else
      Rails.logger.warn "No logged-in employee found"
      @pending_submissions = []
    end
  end

  private

  def set_parking_lot_submission
    @parking_lot_submission = ParkingLotSubmission.find(params[:id])
  end

  def fetch_supervisor_id(employee_id)
    result = ActiveRecord::Base.connection.exec_query(<<-SQL.squish).first
      SELECT Supervisor_ID
      FROM [GSABSS].[dbo].[Employees]
      WHERE EmployeeID = '#{employee_id}'
    SQL
    result&.fetch("Supervisor_ID", nil)
  end

  def fetch_employee_email(emp_id)
    return nil if emp_id.blank?
    row = ActiveRecord::Base.connection.exec_query(<<-SQL.squish).first
      SELECT EE_Email
      FROM [GSABSS].[dbo].[Employees]
      WHERE EmployeeID = '#{emp_id}'
    SQL
    row&.fetch("EE_Email", nil)
  end

  def reload_form_options(emp_record)
    unit       = Unit.find_by(unit_id: emp_record["Unit"])
    department = unit ? Department.find_by(department_id: unit["department_id"]) : nil
    division   = department ? Division.find_by(division_id: department["division_id"]) : nil
    agency     = division ? Agency.find_by(agency_id: division["agency_id"]) : nil

    @agency_options     = Agency.order(:long_name).pluck(:long_name, :agency_id)
    @division_options   = division ? Division.where(agency_id: agency&.agency_id).order(:long_name).pluck(:long_name, :division_id) : []
    @department_options = department ? Department.where(division_id: division&.division_id).order(:long_name).pluck(:long_name, :department_id) : []
    @unit_options       = department ? Unit.where(department_id: department.department_id).order(:unit_id).map { |u| ["#{u.unit_id} - #{u.long_name}", u.unit_id] } : []
  end

  def parking_lot_submission_params
    # NOTE: Do NOT permit :status or :employee_id from the form (we set both server-side)
    params.require(:parking_lot_submission).permit(
      :name,
      :phone,
      :email,
      :agency,
      :division,
      :department,
      :unit,
      parking_lot_vehicles_attributes: [
        :id,
        :make,
        :model,
        :color,
        :year,
        :license_plate,
        :parking_lot,
        :other_parking_lot,
        :_destroy
      ]
    )
  end
end
