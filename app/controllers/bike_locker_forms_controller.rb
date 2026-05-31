class BikeLockerFormsController < ApplicationController
  # Generated controller for BikeLockerForm form
  before_action :set_bike_locker_form, only: [:show, :edit, :update, :pdf, :approve, :deny, :update_status]

  def new
    @bike_locker_form = BikeLockerForm.new

    employee_id = session.dig(:user, "employee_id").to_s
    @employee   = employee_id.present? ? Employee.find_by(employee_id: employee_id) : nil

    unless @employee
      redirect_to login_path, alert: "Please sign in to start a submission." and return
    end

    # Load user groups for field restrictions
    @current_user_groups = current_user_group_ids

    # --- Organization chain (same pattern you use now) ---
    unit        = Unit.resolve_for_employee(@employee)
    department  = unit ? Department.find_by(department_id: unit["department_id"]) : nil
    division    = department ? Division.find_by(division_id: department["division_id"]) : nil
    agency      = division ? Agency.find_by(agency_id: division["agency_id"]) : nil

    # --- Prefill values (everything prefilled exactly like you do now) ---
    @prefill_data = {
      employee_id: @employee["id"],
      name:        [@employee["first_name"], @employee["last_name"]].compact.join(" "),
      phone:       @employee["work_phone"],
      email:       @employee["email"],
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

    @bike_locker_form = BikeLockerForm.new(bike_locker_form_params)
    @bike_locker_form.employee_id = employee_id if @bike_locker_form.respond_to?(:employee_id=)

    if @bike_locker_form.save
      # ROUTING_BLOCK_START
      # Multi-step approval routing (1 steps)
# Delegates to TrackableStatus#start_approval!, which picks the first
# step whose condition matches the submitted record.
@bike_locker_form.start_approval!
redirect_to form_success_path, notice: 'Form submitted and routed for approval.', allow_other_host: false, status: :see_other
      # ROUTING_BLOCK_END
    else
      # Rebuild options on failure (same as in new)
      # (We intentionally repeat the logic to keep this template self-contained.)
      emp = employee_id.present? ? Employee.find_by(employee_id: employee_id) : nil
      unit        = Unit.resolve_for_employee(emp)
      department  = unit ? Department.find_by(department_id: unit["department_id"]) : nil
      division    = department ? Division.find_by(division_id: department["division_id"]) : nil
      agency      = division ? Agency.find_by(agency_id: division["agency_id"]) : nil

      @prefill_data = {
        employee_id: emp&.[]("id"),
        name:        emp ? [emp["first_name"], emp["last_name"]].compact.join(" ") : nil,
        phone:       emp&.[]("work_phone"),
        email:       emp&.[]("email"),
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
    if @bike_locker_form.update(bike_locker_form_params)
      redirect_to @bike_locker_form, notice: 'Submission updated successfully.'
    else
      setup_form_options
      render :edit, status: :unprocessable_entity
    end
  end

  def pdf
    pdf_data = BikeLockerFormPdfGenerator.generate(@bike_locker_form)

    send_data pdf_data,
              filename: "BikeLockerForm_#{@bike_locker_form.id}.pdf",
              type: "application/pdf",
              disposition: "inline"
  end

  def approve
    if @bike_locker_form.respond_to?(:advance_approval!)
      @bike_locker_form.advance_approval!
      notice = @bike_locker_form.approved? ? 'Submission approved.' : 'Approved and routed to the next step.'
      redirect_to inbox_queue_path, notice: notice
    else
      redirect_to inbox_queue_path, alert: 'Unable to approve this submission.'
    end
  end

  def deny
    reason = params[:deny_reason]
    if @bike_locker_form.respond_to?(:denied!)
      @bike_locker_form.denied!
      @bike_locker_form.update(deny_reason: reason) if @bike_locker_form.respond_to?(:deny_reason=) && reason.present?
      redirect_to inbox_queue_path, notice: 'Submission denied.'
    else
      redirect_to inbox_queue_path, alert: 'Unable to deny this submission.'
    end
  end

  def update_status
    new_status = params[:status]
    if new_status.present? && @bike_locker_form.respond_to?("#{new_status}!")
      @bike_locker_form.send("#{new_status}!")
      redirect_to inbox_queue_path, notice: 'Status updated.'
    else
      redirect_to inbox_queue_path, alert: 'Unable to update status.'
    end
  end

  private

  def set_bike_locker_form
    @bike_locker_form = BikeLockerForm.find(params[:id])
  end

  def setup_form_options
    # Build dropdown options around the SAVED form's org chain, not the
    # current viewer's. Otherwise an approver in a different agency would
    # see the saved division/department/unit drop out of the lists and a
    # different value render as the visible default.
    agency_id     = @bike_locker_form&.agency
    division_id   = @bike_locker_form&.division
    department_id = @bike_locker_form&.department

    @prefill_data = {
      employee_id: @bike_locker_form&.employee_id,
      name:        @bike_locker_form&.name,
      phone:       @bike_locker_form&.phone,
      email:       @bike_locker_form&.email,
      agency:      agency_id,
      division:    division_id,
      department:  department_id,
      unit:        @bike_locker_form&.unit
    }

    @agency_options     = Agency.order(:long_name).pluck(:long_name, :agency_id)
    @division_options   = agency_id ? Division.where(agency_id: agency_id).order(:long_name).pluck(:long_name, :division_id) : []
    @department_options = division_id ? Department.where(division_id: division_id).order(:long_name).pluck(:long_name, :department_id) : []
    @unit_options = if department_id
      Unit.where(department_id: department_id)
          .order(:unit_id)
          .map { |u| ["#{u.unit_id} - #{u.long_name}", u.unit_id] }
    else
      []
    end

    # Load user groups for field restrictions
    @current_user_groups = current_user_group_ids
  end

  def bike_locker_form_params
    # Only the baseline fields you asked for
    params.require(:bike_locker_form).permit(
      :name, :phone, :email, :agency, :division, :department, :unit
    )
  end
end
