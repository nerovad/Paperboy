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
      # Multi-step approval routing (2 steps)
      # Step 1: Route to supervisor
      employee = Employee.find_by(EmployeeID: session.dig(:user, "employee_id"))
      approver_id = employee&.Supervisor_ID&.to_s
      @work_schedule_or_location_update_form.update(status: :step_1_pending, approver_id: approver_id)
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
    pdf_data = WorkScheduleOrLocationUpdatePdfGenerator.generate(@work_schedule_or_location_update_form)

    send_data pdf_data,
              filename: "WorkScheduleOrLocationUpdate_#{@work_schedule_or_location_update_form.id}.pdf",
              type: "application/pdf",
              disposition: "inline"
  end

  def approve
    form = @work_schedule_or_location_update_form

    # Multi-step routing: check current status and route to next step
    if form.step_1_pending?
      # Step 1 approved -> route to step 2
      next_approver_id = determine_approver_for_step(2, form)
      form.update(status: :step_2_pending, approver_id: next_approver_id)
      redirect_to inbox_queue_path, notice: 'Step 1 approved. Form routed to next approver.'
    elsif form.step_2_pending?
      # Step 2 approved -> final approval
      form.approved!
      redirect_to inbox_queue_path, notice: 'Form fully approved.'
    elsif form.respond_to?(:approved!)
      # Fallback for single-step approval
      form.approved!
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

    # For edit, use the form's stored values to load the select options
    # This ensures the cascading selects show the correct options for the form's data
    if @work_schedule_or_location_update_form&.persisted?
      form = @work_schedule_or_location_update_form
      agency_id = form.agency
      division_id = form.division
      department_id = form.department
    else
      # For create failure, use current user's organization hierarchy
      emp = employee_id.present? ? Employee.find_by(EmployeeID: employee_id) : nil
      unit        = emp ? Unit.find_by(unit_id: emp["Unit"]) : nil
      department  = unit ? Department.find_by(department_id: unit["department_id"]) : nil
      division    = department ? Division.find_by(division_id: department["division_id"]) : nil
      agency      = division ? Agency.find_by(agency_id: division["agency_id"]) : nil

      agency_id = agency&.agency_id
      division_id = division&.division_id
      department_id = department&.department_id
    end

    @prefill_data = {
      employee_id: @work_schedule_or_location_update_form&.employee_id,
      name:        @work_schedule_or_location_update_form&.name,
      phone:       @work_schedule_or_location_update_form&.phone,
      email:       @work_schedule_or_location_update_form&.email,
      agency:      agency_id,
      division:    division_id,
      department:  department_id,
      unit:        @work_schedule_or_location_update_form&.unit
    }

    @agency_options = Agency.order(:long_name).pluck(:long_name, :agency_id)
    @division_options = agency_id ? Division.where(agency_id: agency_id).order(:long_name).pluck(:long_name, :division_id) : []
    @department_options = division_id ? Department.where(division_id: division_id).order(:long_name).pluck(:long_name, :department_id) : []
    @unit_options = if department_id
      Unit.where(department_id: department_id)
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

  # Determine the approver for a given routing step based on form template configuration
  def determine_approver_for_step(step_number, form)
    form_template = FormTemplate.find_by(class_name: 'WorkScheduleOrLocationUpdateForm')
    return nil unless form_template

    routing_step = form_template.routing_steps.find_by(step_number: step_number)
    return nil unless routing_step

    case routing_step.routing_type
    when 'supervisor'
      # Look up the submitter's supervisor
      employee = Employee.find_by(EmployeeID: form.employee_id)
      employee&.Supervisor_ID&.to_s
    when 'department_head'
      # Look up the submitter's department head
      employee = Employee.find_by(EmployeeID: form.employee_id)
      unit = employee ? Unit.find_by(unit_id: employee["Unit"]) : nil
      department = unit ? Department.find_by(department_id: unit["department_id"]) : nil
      department&.department_head_id&.to_s
    when 'employee'
      # Route to the specific employee configured in the routing step
      routing_step.employee_id.to_s
    end
  end
end
