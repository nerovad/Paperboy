class OshaReportsController < ApplicationController
  before_action :set_osha_report, only: [:show, :edit, :update, :pdf, :approve, :deny, :update_status]

  def new
    @osha_report = OshaReport.new

    employee_id = session.dig(:user, "employee_id").to_s
    @employee   = employee_id.present? ? Employee.find_by(employee_id: employee_id) : nil

    unless @employee
      redirect_to login_path, alert: "Please sign in to start a submission." and return
    end

    @current_user_groups = current_user_group_ids

    unit        = Unit.find_by(unit_id: @employee.unit)
    department  = unit ? Department.find_by(department_id: unit.department_id) : nil
    division    = department ? Division.find_by(division_id: department.division_id) : nil
    agency      = division ? Agency.find_by(agency_id: division.agency_id) : nil

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
    @division_options = agency ? Division.where(agency_id: agency.agency_id).order(:long_name).pluck(:long_name, :division_id) : []
    @department_options = division ? Department.where(division_id: division.division_id).order(:long_name).pluck(:long_name, :department_id) : []
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

    @osha_report = OshaReport.new(osha_report_params)
    @osha_report.employee_id = employee_id if @osha_report.respond_to?(:employee_id=)

    if @osha_report.save
      redirect_to form_success_path, allow_other_host: false, status: :see_other
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
    if @osha_report.update(osha_report_params)
      redirect_to @osha_report, notice: 'Submission updated successfully.'
    else
      setup_form_options
      render :edit, status: :unprocessable_entity
    end
  end

  def pdf
    pdf_data = OshaReportPdfGenerator.generate(@osha_report)

    send_data pdf_data,
              filename: "OshaReport_#{@osha_report.id}.pdf",
              type: "application/pdf",
              disposition: "inline"
  end

  def approve
    if @osha_report.respond_to?(:approved!)
      @osha_report.approved!
      redirect_to inbox_queue_path, notice: 'Submission approved.'
    else
      redirect_to inbox_queue_path, alert: 'Unable to approve this submission.'
    end
  end

  def deny
    reason = params[:deny_reason]
    if @osha_report.respond_to?(:denied!)
      @osha_report.denied!
      @osha_report.update(deny_reason: reason) if @osha_report.respond_to?(:deny_reason=) && reason.present?
      redirect_to inbox_queue_path, notice: 'Submission denied.'
    else
      redirect_to inbox_queue_path, alert: 'Unable to deny this submission.'
    end
  end

  def update_status
    new_status = params[:status]
    if new_status.present? && @osha_report.respond_to?("#{new_status}!")
      @osha_report.send("#{new_status}!")
      redirect_to inbox_queue_path, notice: 'Status updated.'
    else
      redirect_to inbox_queue_path, alert: 'Unable to update status.'
    end
  end

  private

  def set_osha_report
    @osha_report = OshaReport.find(params[:id])
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

  def osha_report_params
    params.require(:osha_report).permit(
      :name, :phone, :email, :agency, :division, :department, :unit,
      :street, :city, :state, :zip, :date_of_birth, :date_hired, :sex,
      :name_of_physician_or_other_health_care_professional,
      :was_treatment_given_away_from_the_worksite,
      :facility_name, :facility_street_address, :facility_city,
      :facility_state, :facility_zip,
      :was_the_employee_treated_in_an_emergency_room,
      :was_the_employee_hospitalized_overnight_as_an_inpatient,
      :case_number_from_the_log, :date_of_injury_or_illness,
      :time_employee_began_work, :time_of_event,
      :what_happened_tell_us_how_the_injury_occurred,
      :what_was_the_injury_or_illness,
      :what_was_the_employee_doing_just_before_the_incident_occurred,
      :what_object_or_substance_directly_harmed_the_employee,
      :did_employee_die, :date_of_death
    )
  end
end
