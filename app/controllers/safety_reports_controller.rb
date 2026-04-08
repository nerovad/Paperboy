class SafetyReportsController < ApplicationController
  before_action :set_safety_report, only: [:show, :edit, :update, :pdf, :approve, :deny, :update_status]

  def new
    @safety_report = SafetyReport.new

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

    # --- Prefill values ---
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

    @safety_report = SafetyReport.new(safety_report_params)
    @safety_report.employee_id = employee_id if @safety_report.respond_to?(:employee_id=)

    if @safety_report.save
      # Route to submitter's supervisor for approval
      employee = Employee.find_by(employee_id: session.dig(:user, "employee_id"))
      supervisor_id = employee&.supervisor_id&.to_s
      @safety_report.update(approver_id: supervisor_id)

      # Multi-step approval routing (1 step)
      # Step 1: supervisor
      employee = Employee.find_by(employee_id: session.dig(:user, "employee_id"))
      approver_id = employee&.supervisor_id&.to_s
      @safety_report.update(status: :step_1_pending, approver_id: approver_id)
      # TODO: Send notification to supervisor
      redirect_to form_success_path, notice: 'Form submitted and routed to supervisor for approval.', allow_other_host: false, status: :see_other
    else
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
  end

  def edit
    setup_form_options
  end

  def update
    if @safety_report.update(safety_report_params)
      # Auto-create OSHA 301 when Gary marks as reportable
      if @safety_report.osha_reportable == 'Yes' && @safety_report.osha301_form.blank?
        @safety_report.create_osha301!
      end

      # Multi-step approval routing (1 step)
      employee = Employee.find_by(employee_id: session.dig(:user, "employee_id"))
      approver_id = employee&.supervisor_id&.to_s
      @safety_report.update(status: :step_1_pending, approver_id: approver_id)
      # TODO: Send notification to supervisor
      redirect_to form_success_path, notice: 'Form submitted and routed to supervisor for approval.', allow_other_host: false, status: :see_other
    else
      setup_form_options
      render :edit, status: :unprocessable_entity
    end
  end

  def pdf
    pdf_data = SafetyReportPdfGenerator.generate(@safety_report)

    send_data pdf_data,
              filename: "SafetyReport_#{@safety_report.id}.pdf",
              type: "application/pdf",
              disposition: "inline"
  end

  def approve
    if @safety_report.respond_to?(:approved!)
      @safety_report.approved!
      redirect_to inbox_queue_path, notice: 'Submission approved.'
    else
      redirect_to inbox_queue_path, alert: 'Unable to approve this submission.'
    end
  end

  def deny
    reason = params[:deny_reason]
    if @safety_report.respond_to?(:denied!)
      @safety_report.denied!
      @safety_report.update(deny_reason: reason) if @safety_report.respond_to?(:deny_reason=) && reason.present?
      redirect_to inbox_queue_path, notice: 'Submission denied.'
    else
      redirect_to inbox_queue_path, alert: 'Unable to deny this submission.'
    end
  end

  def update_status
    new_status = params[:status]
    if new_status.present? && @safety_report.respond_to?("#{new_status}!")
      @safety_report.send("#{new_status}!")
      redirect_to inbox_queue_path, notice: 'Status updated.'
    else
      redirect_to inbox_queue_path, alert: 'Unable to update status.'
    end
  end

  private

  def set_safety_report
    @safety_report = SafetyReport.find(params[:id])
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

    @current_user_groups = current_user_group_ids
  end

  def safety_report_params
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

    if session.dig(:user, 'employee_id').to_s == SafetyReport::GARY_HOWARD_ID
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

    params.require(:safety_report).permit(permitted)
  end
end
