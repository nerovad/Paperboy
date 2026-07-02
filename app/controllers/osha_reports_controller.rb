class OshaReportsController < ApplicationController
  before_action :set_osha_report, only: [ :show, :edit, :update, :pdf, :approve, :deny, :update_status ]

  def new
    @osha_report = OshaReport.new

    employee_id = session.dig(:user, "employee_id").to_s
    @employee   = employee_id.present? ? Employee.find_by(employee_id: employee_id) : nil

    unless @employee
      redirect_to login_path, alert: "Please sign in to start a submission." and return
    end

    @current_user_groups = current_user_group_ids

    unit        = Unit.resolve_for_employee(@employee)
    department  = unit ? Department.find_by(department_id: unit.department_id) : nil
    division    = department ? Division.find_by(division_id: department.division_id) : nil
    agency      = division ? Agency.find_by(agency_id: division.agency_id) : nil

    @prefill_data = {
      employee_id: @employee.employee_id,
      name:        [ @employee.first_name, @employee.last_name ].compact.join(" "),
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
          .map { |u| [ "#{u.unit_id} - #{u.long_name}", u.unit_id ] }
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
# ROUTING_BLOCK_START
# Multi-step approval routing (1 steps)
# Step 1: supervisor
# Look up the submitter's supervisor
employee = Employee.find_by(employee_id: session.dig(:user, "employee_id"))
approver_id = employee&.supervisor_id&.to_s
@osha_report.update(status: :step_1_pending, approver_id: approver_id)
# TODO: Send notification to supervisor
redirect_to form_success_path, notice: "Form submitted and routed to supervisor for approval.", allow_other_host: false, status: :see_other
      # ROUTING_BLOCK_END
    else
      emp = employee_id.present? ? Employee.find_by(employee_id: employee_id) : nil
      unit        = Unit.resolve_for_employee(emp)
      department  = unit ? Department.find_by(department_id: unit.department_id) : nil
      division    = department ? Division.find_by(division_id: department.division_id) : nil
      agency      = division ? Agency.find_by(agency_id: division.agency_id) : nil

      @prefill_data = {
        employee_id: emp&.employee_id,
        name:        emp ? [ emp&.first_name, emp&.last_name ].compact.join(" ") : nil,
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
            .map { |u| [ "#{u.unit_id} - #{u.long_name}", u.unit_id ] }
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
      redirect_to form_success_path,
                  notice: "Form updated successfully.",
                  allow_other_host: false,
                  status: :see_other
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
    if @osha_report.respond_to?(:advance_approval!)
      @osha_report.advance_approval!
      notice = @osha_report.approved? ? "Submission approved." : "Approved and routed to the next step."
      redirect_to inbox_queue_path, notice: notice
    else
      redirect_to inbox_queue_path, alert: "Unable to approve this submission."
    end
  end

  def deny
    reason = params[:deny_reason]
    if @osha_report.respond_to?(:denied!)
      @osha_report.denied!
      @osha_report.update(deny_reason: reason) if @osha_report.respond_to?(:deny_reason=) && reason.present?
      redirect_to inbox_queue_path, notice: "Submission denied."
    else
      redirect_to inbox_queue_path, alert: "Unable to deny this submission."
    end
  end

  def update_status
    new_status = params[:status]
    if update_trackable_status(@osha_report, new_status)
      redirect_to inbox_queue_path, notice: "Status updated."
    else
      redirect_to inbox_queue_path, alert: "Unable to update status."
    end
  end

  private

  def set_osha_report
    @osha_report = OshaReport.find(params[:id])
  end

  def setup_form_options
    # Build dropdown options around the SAVED report's org chain, not the
    # current viewer's. Otherwise an approver in a different agency would
    # see the saved division/department/unit drop out of the lists and a
    # different value render as the visible default.
    agency_id     = @osha_report&.agency
    division_id   = @osha_report&.division
    department_id = @osha_report&.department

    @prefill_data = {
      employee_id: @osha_report&.employee_id,
      name:        @osha_report&.name,
      phone:       @osha_report&.phone,
      email:       @osha_report&.email,
      agency:      agency_id,
      division:    division_id,
      department:  department_id,
      unit:        @osha_report&.unit
    }

    @agency_options     = Agency.order(:long_name).pluck(:long_name, :agency_id)
    @division_options   = agency_id ? Division.where(agency_id: agency_id).order(:long_name).pluck(:long_name, :division_id) : []
    @department_options = division_id ? Department.where(division_id: division_id).order(:long_name).pluck(:long_name, :department_id) : []
    @unit_options = if department_id
      Unit.where(department_id: department_id)
          .order(:unit_id)
          .map { |u| [ "#{u.unit_id} - #{u.long_name}", u.unit_id ] }
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
      :did_employee_die, :date_of_death,
      :case_classification, :case_type, :restricted_duty_days
    )
  end
end
