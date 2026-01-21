class WorkScheduleOrLocationUpdateFormsController < ApplicationController
  # Generated controller for WorkScheduleOrLocationUpdateForm form
  before_action :set_work_schedule_or_location_update_form, only: [:show, :edit, :update, :pdf, :approve, :deny, :update_status]

  def new
    @work_schedule_or_location_update_form = WorkScheduleOrLocationUpdateForm.new

    employee_id = session.dig(:user, "employee_id").to_s
    @employee   = employee_id.present? ? Employee.find_by(EmployeeID: employee_id) : nil

    unless @employee
      redirect_to login_path, alert: "Please sign in to start a submission." and return
    end

    # Load user groups for field restrictions
    @current_user_groups = fetch_user_groups(employee_id)

    # --- Organization chain (same pattern you use now) ---
    unit        = Unit.find_by(unit_id: @employee["Unit"])
    department  = unit ? Department.find_by(department_id: unit["department_id"]) : nil
    division    = department ? Division.find_by(division_id: department["division_id"]) : nil
    agency      = division ? Agency.find_by(agency_id: division["agency_id"]) : nil

    # --- Prefill values (everything prefilled exactly like you do now) ---
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

    # --- Select options (IDs/order match gsabss_selects_controller.js expectations) ---
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

    # Unit label = "unit_id - long_name", value = unit_id (your current pattern)
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
    employee_id   = employee&.dig("employee_id").to_s

    @work_schedule_or_location_update_form = WorkScheduleOrLocationUpdateForm.new(work_schedule_or_location_update_form_params)
    @work_schedule_or_location_update_form.employee_id = employee_id if @work_schedule_or_location_update_form.respond_to?(:employee_id=)

    if @work_schedule_or_location_update_form.save
      # Keep success behavior simple for the template; you can extend per form.
      # Multi-step approval routing (2 steps)
# Step 1: supervisor
# Look up the submitter's supervisor
employee = Employee.find_by(EmployeeID: session.dig(:user, "employee_id"))
approver_id = employee&.Supervisor_ID&.to_s
@work_schedule_or_location_update_form.update(status: :step_1_pending, approver_id: approver_id)
# TODO: Send notification to supervisor
redirect_to form_success_path, notice: 'Form submitted and routed to supervisor for approval.', allow_other_host: false, status: :see_other
    else
      # Rebuild options on failure (same as in new)
      # (We intentionally repeat the logic to keep this template self-contained.)
      emp = employee_id.present? ? Employee.find_by(EmployeeID: employee_id) : nil
      unit        = emp ? Unit.find_by(unit_id: emp["Unit"]) : nil
      department  = unit ? Department.find_by(department_id: unit["department_id"]) : nil
      division    = department ? Division.find_by(division_id: department["division_id"]) : nil
      agency      = division ? Agency.find_by(agency_id: division["agency_id"]) : nil

      @prefill_data = {
        employee_id: emp&.[]("EmployeeID"),
        name:        emp ? [emp["First_Name"], emp["Last_Name"]].compact.join(" ") : nil,
        phone:       emp&.[]("Work_Phone"),
        email:       emp&.[]("EE_Email"),
        agency:      agency&.agency_id,
        division:    division&.division_id,
        department:  department&.department_id,
        unit:        unit&.unit_id
      }

      @agency_options = Agency.order(:long_name).pluck(:long_name, :agency_id)
      @division_options = agency ? Division.where(agency_id: agency.agency_id).order(:long_name).pluck(:long_name, :division_id) : []
      @department_options = division ? Department.where(division_id: division.division_id).order(:long_name).pluck(:long_name, :department_id) : []
      @unit_options = if department
        Unit.where(department_id: department.department_id)
            .order(:unit_id)
            .map { |u| ["#{u.unit_id} - #{u.long_name}", u.unit_id] }
      else
        []
      end

      render :new, status: :unprocessable_entity
    end
  end

  def show
    # Display the submission details
  end

  def edit
    # Edit form - rebuild options same as new
    setup_form_options
  end

  def update
    if @work_schedule_or_location_update_form.update(work_schedule_or_location_update_form_params)
      redirect_to @work_schedule_or_location_update_form, notice: 'Submission updated successfully.'
    else
      setup_form_options
      render :edit, status: :unprocessable_entity
    end
  end

  def pdf
    # Generate PDF for this submission
    respond_to do |format|
      format.pdf do
        render pdf: "work_schedule_or_location_update_form_#{@work_schedule_or_location_update_form.id}",
               template: 'work_schedule_or_location_update_forms/pdf',
               layout: 'pdf',
               disposition: 'inline'
      end
      format.html { redirect_to @work_schedule_or_location_update_form }
    end
  end

  def approve
    if @work_schedule_or_location_update_form.respond_to?(:approved!)
      @work_schedule_or_location_update_form.approved!
      redirect_to inbox_queue_path, notice: 'Submission approved.'
    else
      redirect_to inbox_queue_path, alert: 'Unable to approve this submission.'
    end
  end

  def deny
    reason = params[:deny_reason]
    if @work_schedule_or_location_update_form.respond_to?(:denied!)
      @work_schedule_or_location_update_form.denied!
      @work_schedule_or_location_update_form.update(deny_reason: reason) if @work_schedule_or_location_update_form.respond_to?(:deny_reason=) && reason.present?
      redirect_to inbox_queue_path, notice: 'Submission denied.'
    else
      redirect_to inbox_queue_path, alert: 'Unable to deny this submission.'
    end
  end

  def update_status
    new_status = params[:status]
    if new_status.present? && @work_schedule_or_location_update_form.respond_to?("#{new_status}!")
      @work_schedule_or_location_update_form.send("#{new_status}!")
      redirect_to inbox_queue_path, notice: 'Status updated.'
    else
      redirect_to inbox_queue_path, alert: 'Unable to update status.'
    end
  end

  private

  def set_work_schedule_or_location_update_form
    @work_schedule_or_location_update_form = WorkScheduleOrLocationUpdateForm.find(params[:id])
  end

  def setup_form_options
    employee_id = session.dig(:user, "employee_id").to_s
    emp = employee_id.present? ? Employee.find_by(EmployeeID: employee_id) : nil
    unit        = emp ? Unit.find_by(unit_id: emp["Unit"]) : nil
    department  = unit ? Department.find_by(department_id: unit["department_id"]) : nil
    division    = department ? Division.find_by(division_id: department["division_id"]) : nil
    agency      = division ? Agency.find_by(agency_id: division["agency_id"]) : nil

    @prefill_data = {
      employee_id: emp&.[]("EmployeeID"),
      name:        emp ? [emp["First_Name"], emp["Last_Name"]].compact.join(" ") : nil,
      phone:       emp&.[]("Work_Phone"),
      email:       emp&.[]("EE_Email"),
      agency:      agency&.agency_id,
      division:    division&.division_id,
      department:  department&.department_id,
      unit:        unit&.unit_id
    }

    @agency_options = Agency.order(:long_name).pluck(:long_name, :agency_id)
    @division_options = agency ? Division.where(agency_id: agency.agency_id).order(:long_name).pluck(:long_name, :division_id) : []
    @department_options = division ? Department.where(division_id: division.division_id).order(:long_name).pluck(:long_name, :department_id) : []
    @unit_options = if department
      Unit.where(department_id: department.department_id)
          .order(:unit_id)
          .map { |u| ["#{u.unit_id} - #{u.long_name}", u.unit_id] }
    else
      []
    end

    # Load user groups for field restrictions
    @current_user_groups = fetch_user_groups(employee_id)
  end

  def fetch_user_groups(employee_id)
    return [] if employee_id.blank?

    result = ActiveRecord::Base.connection.execute(
      "SELECT GroupID FROM GSABSS.dbo.Employee_Groups WHERE EmployeeID = #{employee_id}"
    )
    result.map { |row| row['GroupID'] }
  rescue
    []
  end

  def work_schedule_or_location_update_form_params
    # Only the baseline fields you asked for
    params.require(:work_schedule_or_location_update_form).permit(
      :name, :phone, :email, :agency, :division, :department, :unit
    )
  end
end
