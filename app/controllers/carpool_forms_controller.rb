class CarpoolFormsController < ApplicationController
  # Minimal controller for the two-page template (Employee Info + Agency Info)

  def new
    @carpool_form = CarpoolForm.new

    employee_id = session.dig(:user, "employee_id").to_s
    @employee   = employee_id.present? ? Employee.find_by(employee_id: employee_id) : nil

    unless @employee
      redirect_to login_path, alert: "Please sign in to start a submission." and return
    end

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

    @carpool_form = CarpoolForm.new(carpool_form_params)
    @carpool_form.employee_id = employee_id if @carpool_form.respond_to?(:employee_id=)

    if @carpool_form.save
      # Keep success behavior simple for the template; you can extend per form.
      # Route to specific employee for approval
@carpool_form.update(status: :pending, approver_id: 136626)
# TODO: Send notification to employee with ID 136626
redirect_to form_success_path, notice: 'Form submitted and routed for approval.', allow_other_host: false, status: :see_other
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

  private

  def carpool_form_params
    # Only the baseline fields you asked for
    params.require(:carpool_form).permit(
      :name, :phone, :email, :agency, :division, :department, :unit
    )
  end
end
