# app/controllers/parking_lot_submissions_controller.rb
class ParkingLotSubmissionsController < ApplicationController
  before_action :set_parking_lot_submission, only: [:show, :pdf, :approve, :deny]

  def new
    @parking_lot_submission = ParkingLotSubmission.new
    @parking_lot_submission.parking_lot_vehicles.build

    employee_id = session[:user]["employee_id"]
    @employee = Employee.find_by(EmployeeID: employee_id)

    # Lookup by employee’s unit code
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

    # Dropdowns (you can sort by long_name if needed)
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
  end

  def create
    employee = session[:user]
    supervisor_id = fetch_supervisor_id(employee["employee_id"])

    Rails.logger.info "Creating submission for employee #{employee["employee_id"]}, supervisor: #{supervisor_id}"

    @parking_lot_submission = ParkingLotSubmission.new(parking_lot_submission_params)

    # Trust the session, not the form, for identity and initial status
    @parking_lot_submission.employee_id  = employee["employee_id"].to_s
    @parking_lot_submission.status       = 0  # submitted
    @parking_lot_submission.supervisor_id = supervisor_id

    if @parking_lot_submission.save
      redirect_to form_success_path, allow_other_host: false, status: :see_other
    else
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
