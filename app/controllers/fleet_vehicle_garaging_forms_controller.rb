# frozen_string_literal: true

class FleetVehicleGaragingFormsController < ApplicationController
  # Generated controller for FleetVehicleGaragingForm form
  before_action :set_fleet_vehicle_garaging_form, only: %i[show edit update pdf approve deny update_status]

  def new
    @fleet_vehicle_garaging_form = FleetVehicleGaragingForm.new
    @fleet_vehicle_garaging_form.fleet_vehicles.build if @fleet_vehicle_garaging_form.fleet_vehicles.empty?

    employee_id = session.dig(:user, 'employee_id').to_s
    @employee   = employee_id.present? ? Employee.find_by(employee_id: employee_id) : nil

    redirect_to login_path, alert: 'Please sign in to start a submission.' and return unless @employee

    # Load user groups for field restrictions
    @current_user_groups = current_user_group_ids

    # --- Organization chain (same pattern you use now) ---
    unit        = Unit.find_by(unit_id: @employee['unit'])
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
  end

  def create
    employee      = session[:user]
    employee_id   = employee&.dig('employee_id').to_s

    @fleet_vehicle_garaging_form = FleetVehicleGaragingForm.new(fleet_vehicle_garaging_form_params)
    @fleet_vehicle_garaging_form.employee_id = employee_id if @fleet_vehicle_garaging_form.respond_to?(:employee_id=)

    if @fleet_vehicle_garaging_form.save
      # ROUTING_BLOCK_START
      # Multi-step approval routing (1 steps)
      # Delegates to TrackableStatus#start_approval!, which picks the first
      # step whose condition matches the submitted record.
      @fleet_vehicle_garaging_form.start_approval!
      redirect_to form_success_path, notice: 'Form submitted and routed for approval.', allow_other_host: false, status: :see_other
      # ROUTING_BLOCK_END
    else
      # Rebuild options on failure (same as in new)
      # (We intentionally repeat the logic to keep this template self-contained.)
      emp = employee_id.present? ? Employee.find_by(employee_id: employee_id) : nil
      unit        = emp ? Unit.find_by(unit_id: emp['unit']) : nil
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

      render :new, status: :unprocessable_entity
    end
  end

  def show
    # Display the submission details
  end

  def edit
    # Edit form - rebuild options same as new
    @fleet_vehicle_garaging_form.fleet_vehicles.build if @fleet_vehicle_garaging_form.fleet_vehicles.empty?
    setup_form_options
  end

  def update
    if @fleet_vehicle_garaging_form.update(fleet_vehicle_garaging_form_params)
      redirect_to @fleet_vehicle_garaging_form, notice: 'Submission updated successfully.'
    else
      setup_form_options
      render :edit, status: :unprocessable_entity
    end
  end

  def pdf
    pdf_data = FleetVehicleGaragingFormPdfGenerator.generate(@fleet_vehicle_garaging_form)

    send_data pdf_data,
              filename: "FleetVehicleGaragingForm_#{@fleet_vehicle_garaging_form.id}.pdf",
              type: 'application/pdf',
              disposition: 'inline'
  end

  def approve
    if @fleet_vehicle_garaging_form.respond_to?(:advance_approval!)
      @fleet_vehicle_garaging_form.advance_approval!
      notice = @fleet_vehicle_garaging_form.approved? ? 'Submission approved.' : 'Approved and routed to the next step.'
      redirect_to inbox_queue_path, notice: notice
    else
      redirect_to inbox_queue_path, alert: 'Unable to approve this submission.'
    end
  end

  def deny
    reason = params[:deny_reason]
    if @fleet_vehicle_garaging_form.respond_to?(:denied!)
      # Set the reason in the same save as the status change so the denial email
      # (fired by TrackableStatus on the status transition) can interpolate it.
      @fleet_vehicle_garaging_form.deny_reason = reason if @fleet_vehicle_garaging_form.respond_to?(:deny_reason=) && reason.present?
      @fleet_vehicle_garaging_form.denied!
      redirect_to inbox_queue_path, notice: 'Submission denied.'
    else
      redirect_to inbox_queue_path, alert: 'Unable to deny this submission.'
    end
  end

  def update_status
    new_status = params[:status]
    if update_trackable_status(@fleet_vehicle_garaging_form, new_status)
      redirect_to inbox_queue_path, notice: 'Status updated.'
    else
      redirect_to inbox_queue_path, alert: 'Unable to update status.'
    end
  end

  private

  def set_fleet_vehicle_garaging_form
    @fleet_vehicle_garaging_form = FleetVehicleGaragingForm.find(params[:id])
  end

  def setup_form_options
    employee_id = session.dig(:user, 'employee_id').to_s
    emp = employee_id.present? ? Employee.find_by(employee_id: employee_id) : nil
    unit        = emp ? Unit.find_by(unit_id: emp['unit']) : nil
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

    # Load user groups for field restrictions
    @current_user_groups = current_user_group_ids
  end

  def fleet_vehicle_garaging_form_params
    # Only the baseline fields you asked for
    params.require(:fleet_vehicle_garaging_form).permit(
      :name, :phone, :email, :agency, :division, :department, :unit, :location,
      fleet_vehicles_attributes: %i[
        id
        year
        make
        model
        color
        license_plate
        garaging_location
        _destroy
      ]
    )
  end
end
