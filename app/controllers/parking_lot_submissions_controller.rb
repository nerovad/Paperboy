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
  supervisor_id = fetch_supervisor_id(employee_id)

  # Check Union Code from DB (trust server-side)
  union_code = ActiveRecord::Base.connection.exec_query(<<-SQL.squish).first&.fetch("Union_Code", nil).to_s.upcase
    SELECT Union_Code
    FROM [GSABSS].[dbo].[Employees]
    WHERE EmployeeID = '#{employee_id}'
  SQL
  is_mb3 = (union_code == "MB3")

  @parking_lot_submission = ParkingLotSubmission.new(parking_lot_submission_params)
  @parking_lot_submission.employee_id = employee_id

  if is_mb3
    # Auto-approve: no manager routing
    @parking_lot_submission.status        = 1 # manager_approved
    @parking_lot_submission.supervisor_id = nil
    @parking_lot_submission.approved_by   = employee_id # or "SYSTEM"
    @parking_lot_submission.approved_at   = Time.current
  else
    # Normal path: submitted and routed to supervisor
    @parking_lot_submission.status        = 0 # submitted
    @parking_lot_submission.supervisor_id = supervisor_id
  end

  if @parking_lot_submission.save
    if is_mb3
      NotifySecurityJob.perform_later(@parking_lot_submission.id)
      SecurityMailer.notify(@parking_lot_submission).deliver_later
    end

    redirect_to form_success_path, allow_other_host: false, status: :see_other
  else
    @is_mb3 = is_mb3
    base_lots = ["A Lot", "B Lot", "C Lot", "D Lot", "Employee Lot", "Visitor Lot"]
    @allowed_parking_lots = is_mb3 ? (base_lots + ["R Lot"]) : base_lots
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

  @submission.update!(
    status: 1,                        # manager_approved
    approved_by: approver_id,
    approved_at: Time.current
  )

  # send to Security (unchanged, still uses the job)
  NotifySecurityJob.perform_later(@submission.id)

  # NEW: notify the employee who submitted
  SecurityMailer.notify(@submission).deliver_later

  redirect_to parking_lot_submissions_path, notice: "Request approved and sent to Security."
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
