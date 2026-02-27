class LeaveOfAbsenceFormsController < ApplicationController
  # Generated controller for LeaveOfAbsenceForm form
  before_action :set_leave_of_absence_form, only: [:show, :edit, :update, :pdf, :approve, :deny, :update_status]

  def new
    @leave_of_absence_form = LeaveOfAbsenceForm.new

    employee_id = session.dig(:user, "employee_id").to_s
    @employee   = employee_id.present? ? Employee.find_by(employee_id: employee_id) : nil

    unless @employee
      redirect_to login_path, alert: "Please sign in to start a submission." and return
    end

    # Load user groups for field restrictions
    @current_user_groups = current_user_group_ids

    # --- Organization chain (same pattern you use now) ---
    unit        = Unit.find_by(unit_id: @employee.unit)
    department  = unit ? Department.find_by(department_id: unit.department_id) : nil
    division    = department ? Division.find_by(division_id: department.division_id) : nil
    agency      = division ? Agency.find_by(agency_id: division.agency_id) : nil

    # --- Prefill values (everything prefilled exactly like you do now) ---
    @prefill_data = {
      employee_id: @employee.employee_id,
      name:        [@employee.first_name, @employee.last_name].compact.join(" "),
      phone:       @employee.work_phone,
      email:       @employee.email,
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

    @leave_of_absence_form = LeaveOfAbsenceForm.new(leave_of_absence_form_params)
    @leave_of_absence_form.employee_id = employee_id if @leave_of_absence_form.respond_to?(:employee_id=)

    if @leave_of_absence_form.save
      # Keep success behavior simple for the template; you can extend per form.
      # Multi-step approval routing (1 steps)
# Step 1: supervisor
# Look up the submitter's supervisor
employee = Employee.find_by(employee_id: session.dig(:user, "employee_id"))
approver_id = employee&.supervisor_id&.to_s
@leave_of_absence_form.update(status: :step_1_pending, approver_id: approver_id)
# TODO: Send notification to supervisor
# Multi-step approval routing (1 steps)
# Step 1: supervisor
# Look up the submitter's supervisor
employee = Employee.find_by(employee_id: session.dig(:user, "employee_id"))
approver_id = employee&.supervisor_id&.to_s
@leave_of_absence_form.update(status: :step_1_pending, approver_id: approver_id)
# TODO: Send notification to supervisor
redirect_to form_success_path, notice: 'Form submitted and routed to supervisor for approval.', allow_other_host: false, status: :see_other
    else
      # Rebuild options on failure (same as in new)
      # (We intentionally repeat the logic to keep this template self-contained.)
      emp = employee_id.present? ? Employee.find_by(employee_id: employee_id) : nil
      unit        = emp ? Unit.find_by(unit_id: emp&.unit) : nil
      department  = unit ? Department.find_by(department_id: unit.department_id) : nil
      division    = department ? Division.find_by(division_id: department.division_id) : nil
      agency      = division ? Agency.find_by(agency_id: division.agency_id) : nil

      @prefill_data = {
        employee_id: emp&.employee_id,
        name:        emp ? [emp&.first_name, emp&.last_name].compact.join(" ") : nil,
        phone:       emp&.work_phone,
        email:       emp&.email,
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
    if @leave_of_absence_form.update(leave_of_absence_form_params)
      redirect_to @leave_of_absence_form, notice: 'Submission updated successfully.'
    else
      setup_form_options
      render :edit, status: :unprocessable_entity
    end
  end

  def pdf
    pdf_data = LeaveOfAbsenceFormPdfGenerator.generate(@leave_of_absence_form)

    send_data pdf_data,
              filename: "LeaveOfAbsenceForm_#{@leave_of_absence_form.id}.pdf",
              type: "application/pdf",
              disposition: "inline"
  end

  def approve
    if @leave_of_absence_form.respond_to?(:approved!)
      @leave_of_absence_form.approved!
      redirect_to inbox_queue_path, notice: 'Submission approved.'
    else
      redirect_to inbox_queue_path, alert: 'Unable to approve this submission.'
    end
  end

  def deny
    reason = params[:deny_reason]
    if @leave_of_absence_form.respond_to?(:denied!)
      @leave_of_absence_form.denied!
      @leave_of_absence_form.update(deny_reason: reason) if @leave_of_absence_form.respond_to?(:deny_reason=) && reason.present?
      redirect_to inbox_queue_path, notice: 'Submission denied.'
    else
      redirect_to inbox_queue_path, alert: 'Unable to deny this submission.'
    end
  end

  def update_status
    new_status = params[:status]
    if new_status.present? && @leave_of_absence_form.respond_to?("#{new_status}!")
      @leave_of_absence_form.send("#{new_status}!")
      redirect_to inbox_queue_path, notice: 'Status updated.'
    else
      redirect_to inbox_queue_path, alert: 'Unable to update status.'
    end
  end

  private

  def set_leave_of_absence_form
    @leave_of_absence_form = LeaveOfAbsenceForm.find(params[:id])
  end

  def setup_form_options
    employee_id = session.dig(:user, "employee_id").to_s
    emp = employee_id.present? ? Employee.find_by(employee_id: employee_id) : nil
    unit        = emp ? Unit.find_by(unit_id: emp&.unit) : nil
    department  = unit ? Department.find_by(department_id: unit.department_id) : nil
    division    = department ? Division.find_by(division_id: department.division_id) : nil
    agency      = division ? Agency.find_by(agency_id: division.agency_id) : nil

    @prefill_data = {
      employee_id: emp&.employee_id,
      name:        emp ? [emp&.first_name, emp&.last_name].compact.join(" ") : nil,
      phone:       emp&.work_phone,
      email:       emp&.email,
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
    @current_user_groups = current_user_group_ids
  end

  def leave_of_absence_form_params
    # Only the baseline fields you asked for
    params.require(:leave_of_absence_form).permit(
      :name, :phone, :email, :agency, :division, :department, :unit
    )
  end
end
