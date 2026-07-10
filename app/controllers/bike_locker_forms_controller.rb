class BikeLockerFormsController < ApplicationController
  # Generated controller for BikeLockerForm form
  before_action :set_bike_locker_form, only: %i[show edit update pdf approve deny update_status]

  def new
    @bike_locker_form = BikeLockerForm.new

    employee_id = session.dig(:user, 'employee_id').to_s
    @employee   = employee_id.present? ? Employee.find_by(employee_id: employee_id) : nil

    redirect_to login_path, alert: 'Please sign in to start a submission.' and return unless @employee

    # Load user groups for field restrictions
    @current_user_groups = current_user_group_ids

    # --- Organization chain (same pattern you use now) ---
    unit        = Unit.resolve_for_employee(@employee)
    department  = unit ? Department.find_by(department_id: unit['department_id']) : nil
    division    = department ? Division.find_by(division_id: department['division_id']) : nil
    agency      = division ? Agency.find_by(agency_id: division['agency_id']) : nil

    # --- Prefill values (everything prefilled exactly like you do now) ---
    @prefill_data = {
      employee_id: @employee['id'],
      name: [@employee['first_name'], @employee['last_name']].compact.join(' '),
      phone: @employee['work_phone'],
      email: @employee['email'],
      agency: agency&.agency_id,
      division: division&.division_id,
      department: department&.department_id,
      unit: unit&.unit_id
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

    setup_locker_options
  end

  # Feeds the lot -> locker dependent dropdown. Returns [number, id] pairs for
  # the available lockers in the chosen lot (JSON).
  def available_lockers
    render json: available_locker_pairs(params[:lot_id], params[:current_locker_id])
  end

  def create
    employee      = session[:user]
    employee_id   = employee&.dig('employee_id').to_s

    @bike_locker_form = BikeLockerForm.new(bike_locker_form_params)
    @bike_locker_form.employee_id = employee_id if @bike_locker_form.respond_to?(:employee_id=)

    saved = ActiveRecord::Base.transaction do
      next false unless @bike_locker_form.save

      # Hold the locker the moment the request is filed so two people can't
      # claim the same one while it sits in the approval queue.
      @bike_locker_form.reserve_locker!
      true
    end

    if saved
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
      department  = unit ? Department.find_by(department_id: unit['department_id']) : nil
      division    = department ? Division.find_by(division_id: department['division_id']) : nil
      agency      = division ? Agency.find_by(agency_id: division['agency_id']) : nil

      @prefill_data = {
        employee_id: emp&.[]('id'),
        name: emp ? [emp['first_name'], emp['last_name']].compact.join(' ') : nil,
        phone: emp&.[]('work_phone'),
        email: emp&.[]('email'),
        agency: agency&.agency_id,
        division: division&.division_id,
        department: department&.department_id,
        unit: unit&.unit_id
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

      setup_locker_options
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
              type: 'application/pdf',
              disposition: 'inline'
  end

  def approve
    if @bike_locker_form.respond_to?(:advance_approval!)
      @bike_locker_form.advance_approval!
      # Final approval turns the held reservation into a firm assignment.
      @bike_locker_form.assign_locker! if @bike_locker_form.approved?
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
      # Denial releases the locker back into the available pool.
      @bike_locker_form.release_locker!
      redirect_to inbox_queue_path, notice: 'Submission denied.'
    else
      redirect_to inbox_queue_path, alert: 'Unable to deny this submission.'
    end
  end

  def update_status
    new_status = params[:status]
    if update_trackable_status(@bike_locker_form, new_status)
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
      name: @bike_locker_form&.name,
      phone: @bike_locker_form&.phone,
      email: @bike_locker_form&.email,
      agency: agency_id,
      division: division_id,
      department: department_id,
      unit: @bike_locker_form&.unit
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

    setup_locker_options
  end

  # Lot dropdown options + the locker options for whichever lot is currently
  # chosen (none on a fresh form). Edit pre-selects the saved lot and keeps the
  # already-chosen locker selectable even though it's now reserved.
  def setup_locker_options
    @lot_options     = BikeLockerLot.order(:name).pluck(:name, :id)
    @selected_lot_id = @bike_locker_form&.locker&.lot_id
    @locker_options  = @selected_lot_id ? available_locker_pairs(@selected_lot_id, @bike_locker_form&.locker_id) : []
  end

  def available_locker_pairs(lot_id, current_locker_id = nil)
    return [] if lot_id.blank?

    lockers = BikeLocker.available_for_lot(lot_id).to_a
    # Keep the locker this submission already holds in the list (it's reserved,
    # so it wouldn't show up as available).
    if current_locker_id.present?
      held = BikeLocker.find_by(id: current_locker_id, lot_id: lot_id)
      if held && lockers.none? { |l| l.id == held.id }
        lockers << held
        lockers.sort_by!(&:locker_number)
      end
    end
    lockers.map { |l| [l.locker_number.to_s, l.id] }
  end

  def bike_locker_form_params
    # Baseline fields + the locker selection. locker_location / locker_number
    # are NOT permitted: they're derived from locker_id in the model.
    params.require(:bike_locker_form).permit(
      :name, :phone, :email, :agency, :division, :department, :unit,
      :locker_id, :number_of_bikes
    )
  end
end
