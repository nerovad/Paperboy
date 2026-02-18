class Rm75FormsController < ApplicationController
  # Generated controller for Rm75Form form
  before_action :set_rm75_form, only: [:show, :edit, :update, :pdf, :approve, :deny, :update_status]

  def new
    @rm75_form = Rm75Form.new

    employee_id = session.dig(:user, "employee_id").to_s
    @employee   = employee_id.present? ? Employee.find_by(EmployeeID: employee_id) : nil

    unless @employee
      redirect_to login_path, alert: "Please sign in to start a submission." and return
    end

    # Load user groups for field restrictions
    @current_user_groups = current_user_group_ids

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

    @rm75_form = Rm75Form.new(rm75_form_params)
    @rm75_form.employee_id = employee_id if @rm75_form.respond_to?(:employee_id=)

    if @rm75_form.save
      # Route to submitter's supervisor for approval
      employee = Employee.find_by(EmployeeID: session.dig(:user, "employee_id"))
      supervisor_id = employee&.Supervisor_ID&.to_s
      @rm75_form.update(approver_id: supervisor_id)

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
    if @rm75_form.update(rm75_form_params)
      # Auto-create OSHA 301 when Gary marks as reportable
      if @rm75_form.osha_reportable == 'Yes' && @rm75_form.osha301_form.blank?
        @rm75_form.create_osha301!
      end

      redirect_to form_success_path, notice: 'Submission updated successfully.', allow_other_host: false, status: :see_other
    else
      setup_form_options
      render :edit, status: :unprocessable_entity
    end
  end

  def pdf
    pdf_data = Rm75FormPdfGenerator.generate(@rm75_form)

    send_data pdf_data,
              filename: "Rm75Form_#{@rm75_form.id}.pdf",
              type: "application/pdf",
              disposition: "inline"
  end

  def approve
    if @rm75_form.respond_to?(:approved!)
      @rm75_form.approved!
      redirect_to inbox_queue_path, notice: 'Submission approved.'
    else
      redirect_to inbox_queue_path, alert: 'Unable to approve this submission.'
    end
  end

  def deny
    reason = params[:deny_reason]
    if @rm75_form.respond_to?(:denied!)
      @rm75_form.denied!
      @rm75_form.update(deny_reason: reason) if @rm75_form.respond_to?(:deny_reason=) && reason.present?
      redirect_to inbox_queue_path, notice: 'Submission denied.'
    else
      redirect_to inbox_queue_path, alert: 'Unable to deny this submission.'
    end
  end

  def update_status
    new_status = params[:status]
    if new_status.present? && @rm75_form.respond_to?("#{new_status}!")
      @rm75_form.send("#{new_status}!")
      redirect_to inbox_queue_path, notice: 'Status updated.'
    else
      redirect_to inbox_queue_path, alert: 'Unable to update status.'
    end
  end

  private

  def set_rm75_form
    @rm75_form = Rm75Form.find(params[:id])
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
    @current_user_groups = current_user_group_ids
  end

  def rm75_form_params
    permitted = [
      :name, :phone, :email, :agency, :division, :department, :unit,
      :report_type, :bloodborne_pathogen_exposure, :supervisor_name,
      :witness_name, :witness_phone, :date_of_injury_or_illness,
      :date_employer_notified, :date_dwc1_given, :who_gave_the_dwc1,
      :date_last_worked, :date_returned_to_work, :missed_full_work_day_,
      :still_off_work, :specific_injury_and_body_part_affected,
      :location_of_incident, :on_employer_premises,
      :department_where_event_occurred, :activity_at_time_of_incident,
      :how_the_injury_occurred, :physician_name, :physician_address,
      :physician_phone, :hospital_name, :hospital_address,
      :hospital_phone, :hospitalized_overnight
    ]

    if session.dig(:user, 'employee_id').to_s == Rm75Form::GARY_HOWARD_ID
      permitted += [
        :investigator_name, :investigator_title, :investigator_phone,
        :nature_of_incident, :cause_of_incident, :root_cause,
        :assessment_of_future_severity_potential,
        :assessment_of_probability_of_recurrence,
        :unsafe_condition_corrected_immediately,
        :checklistprocedurestraining_modified,
        :person_responsible_for_corrective_action, :title,
        :corrective_department, :corrective_phone,
        :targeted_completion_date, :actual_completion_date,
        :osha_recordable, :osha_reportable, :reportable_injury_codes
      ]
    end

    params.require(:rm75_form).permit(permitted)
  end
end
