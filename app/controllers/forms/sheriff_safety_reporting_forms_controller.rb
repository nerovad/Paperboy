# frozen_string_literal: true

module Forms
  class SheriffSafetyReportingFormsController < Forms::BaseController
    before_action :set_sheriff_safety_reporting_form, only: %i[show edit update pdf approve deny update_status]

    def new
      @sheriff_safety_reporting_form = SheriffSafetyReportingForm.new

      employee_id = session.dig(:user, 'employee_id').to_s
      @employee   = employee_id.present? ? Employee.find_by(employee_id: employee_id) : nil

      redirect_to login_path, alert: 'Please sign in to start a submission.' and return unless @employee

      # Load user groups for field restrictions
      @current_user_groups = current_user_group_ids

      # --- Organization chain (same pattern you use now) ---
      unit        = Coa::Unit.resolve_for_employee(@employee)
      department  = unit ? Coa::Department.find_by(department_id: unit.department_id) : nil
      division    = department ? Coa::Division.find_by(division_id: department.division_id) : nil
      agency      = division ? Coa::Agency.find_by(agency_id: division.agency_id) : nil

      # --- Prefill values ---
      @prefill_data = {
        employee_id: @employee.employee_id,
        name: [@employee.first_name, @employee.last_name].compact.join(' '),
        phone: @employee.work_phone,
        email: @employee.email,
        agency: agency&.agency_id,
        division: division&.division_id,
        department: department&.department_id,
        unit: unit&.unit_id,
        supervisor_name: [@employee.supervisor_first_name, @employee.supervisor_last_name].compact.join(' ').presence
      }

      @agency_options = Coa::Agency.order(:long_name).pluck(:long_name, :agency_id)

      @division_options = if agency
                            Coa::Division.where(agency_id: agency.agency_id).order(:long_name).pluck(:long_name, :division_id)
                          else
                            []
                          end

      @department_options = if division
                              Coa::Department.where(division_id: division.division_id).order(:long_name).pluck(:long_name, :department_id)
                            else
                              []
                            end

      @unit_options = if department
                        Coa::Unit.where(department_id: department.department_id)
                                 .order(:unit_id)
                                 .map { |u| ["#{u.unit_id} - #{u.long_name}", u.unit_id] }
                      else
                        []
                      end
    end

    def create
      employee      = session[:user]
      employee_id   = employee&.dig('employee_id').to_s

      @sheriff_safety_reporting_form = SheriffSafetyReportingForm.new(sheriff_safety_reporting_form_params)
      @sheriff_safety_reporting_form.employee_id = employee_id if @sheriff_safety_reporting_form.respond_to?(:employee_id=)

      if @sheriff_safety_reporting_form.save
        # ROUTING_BLOCK_START
        # Multi-step approval routing (2 steps)
        # Delegates to TrackableStatus#start_approval!, which picks the first
        # step whose condition matches the submitted record.
        @sheriff_safety_reporting_form.start_approval!
        redirect_to form_success_path, notice: 'Form submitted and routed for approval.', allow_other_host: false, status: :see_other
        # ROUTING_BLOCK_END
      else
        emp = employee_id.present? ? Employee.find_by(employee_id: employee_id) : nil
        unit        = Coa::Unit.resolve_for_employee(emp)
        department  = unit ? Coa::Department.find_by(department_id: unit.department_id) : nil
        division    = department ? Coa::Division.find_by(division_id: department.division_id) : nil
        agency      = division ? Coa::Agency.find_by(agency_id: division.agency_id) : nil

        @prefill_data = {
          employee_id: emp&.employee_id,
          name: emp ? [emp&.first_name, emp&.last_name].compact.join(' ') : nil,
          phone: emp&.work_phone,
          email: emp&.email,
          agency: agency&.agency_id,
          division: division&.division_id,
          department: department&.department_id,
          unit: unit&.unit_id,
          supervisor_name: emp ? [emp&.supervisor_first_name, emp&.supervisor_last_name].compact.join(' ').presence : nil
        }

        @agency_options = Coa::Agency.order(:long_name).pluck(:long_name, :agency_id)
        @division_options = agency ? Coa::Division.where(agency_id: agency.agency_id).order(:long_name).pluck(:long_name, :division_id) : []
        @department_options = division ? Coa::Department.where(division_id: division.division_id).order(:long_name).pluck(:long_name, :department_id) : []
        @unit_options = if department
                          Coa::Unit.where(department_id: department.department_id)
                                   .order(:unit_id)
                                   .map { |u| ["#{u.unit_id} - #{u.long_name}", u.unit_id] }
                        else
                          []
                        end

        render :new, status: :unprocessable_entity
      end
    end

    def show; end

    def edit
      setup_form_options
    end

    def update
      if @sheriff_safety_reporting_form.update(sheriff_safety_reporting_form_params)
        # Auto-create OSHA Report when the safety officer marks the incident as
        # either OSHA recordable or OSHA reportable. The editing user becomes the
        # approver on the spawned OSHA Report.
        @sheriff_safety_reporting_form.create_osha_report!(approver_id: session.dig(:user, 'employee_id')) if @sheriff_safety_reporting_form.osha_report_required? && @sheriff_safety_reporting_form.osha_report.blank?

        redirect_to form_success_path,
                    notice: 'Form updated successfully.',
                    allow_other_host: false,
                    status: :see_other
      else
        setup_form_options
        render :edit, status: :unprocessable_entity
      end
    end

    def pdf
      pdf_data = SheriffSafetyReportingFormPdfGenerator.generate(@sheriff_safety_reporting_form)

      send_data pdf_data,
                filename: "SheriffSafetyReportingForm_#{@sheriff_safety_reporting_form.id}.pdf",
                type: 'application/pdf',
                disposition: 'inline'
    end

    def approve
      if @sheriff_safety_reporting_form.respond_to?(:advance_approval!)
        @sheriff_safety_reporting_form.advance_approval!
        notice = @sheriff_safety_reporting_form.approved? ? 'Submission approved.' : 'Approved and routed to the next step.'
        redirect_to inbox_queue_path, notice: notice
      else
        redirect_to inbox_queue_path, alert: 'Unable to approve this submission.'
      end
    end

    def deny
      reason = params[:deny_reason]
      if @sheriff_safety_reporting_form.respond_to?(:denied!)
        @sheriff_safety_reporting_form.denied!
        @sheriff_safety_reporting_form.update(deny_reason: reason) if @sheriff_safety_reporting_form.respond_to?(:deny_reason=) && reason.present?
        redirect_to inbox_queue_path, notice: 'Submission denied.'
      else
        redirect_to inbox_queue_path, alert: 'Unable to deny this submission.'
      end
    end

    def update_status
      new_status = params[:status]
      if update_trackable_status(@sheriff_safety_reporting_form, new_status)
        redirect_to inbox_queue_path, notice: 'Status updated.'
      else
        redirect_to inbox_queue_path, alert: 'Unable to update status.'
      end
    end

    private

    def set_sheriff_safety_reporting_form
      @sheriff_safety_reporting_form = SheriffSafetyReportingForm.find(params[:id])
    end

    def setup_form_options
      # Build dropdown options around the SAVED report's org chain, not the
      # current viewer's. Otherwise a safety officer in a different agency
      # opens Sabrina's HCA form, the division/department/unit selects only
      # contain *their* agency's options, the saved values don't match any
      # option, and browsers render the first option (alphabetically often
      # "Cannabis Business License Program") as the visible default.
      agency_id     = @sheriff_safety_reporting_form&.agency
      division_id   = @sheriff_safety_reporting_form&.division
      department_id = @sheriff_safety_reporting_form&.department

      @prefill_data = {
        employee_id: @sheriff_safety_reporting_form&.employee_id,
        name: @sheriff_safety_reporting_form&.name,
        phone: @sheriff_safety_reporting_form&.phone,
        email: @sheriff_safety_reporting_form&.email,
        agency: agency_id,
        division: division_id,
        department: department_id,
        unit: @sheriff_safety_reporting_form&.unit
      }

      @agency_options     = Coa::Agency.order(:long_name).pluck(:long_name, :agency_id)
      @division_options   = agency_id ? Coa::Division.where(agency_id: agency_id).order(:long_name).pluck(:long_name, :division_id) : []
      @department_options = division_id ? Coa::Department.where(division_id: division_id).order(:long_name).pluck(:long_name, :department_id) : []
      @unit_options = if department_id
                        Coa::Unit.where(department_id: department_id)
                                 .order(:unit_id)
                                 .map { |u| ["#{u.unit_id} - #{u.long_name}", u.unit_id] }
                      else
                        []
                      end

      @current_user_groups = current_user_group_ids
    end

    def sheriff_safety_reporting_form_params
      permitted = %i[
        name phone email agency division department unit
        report_type bloodborne_pathogen_exposure supervisor_name
        witness_name witness_phone date_of_injury_or_illness
        date_employer_notified date_dwc1_given who_gave_the_dwc1
        date_last_worked date_returned_to_work missed_full_work_day_
        still_off_work specific_injury_and_body_part_affected
        location_of_incident on_employer_premises
        department_where_event_occurred activity_at_time_of_incident
        how_the_injury_occurred physician_name physician_address
        physician_phone hospital_name hospital_address
        hospital_phone hospitalized_overnight
        medical_record_number_for_the_employee impacted_employee
        impacted_employees_email impacted_employees_phone
        impacted_employees_supervisor location_description
        is_the_source_blood_tested is_the_employees_blood_tested
        source_patient_medical_number employee_medical_number
        other_hospital other_hospital_address other_hospital_phone
      ]

      if current_user_group_names.include?('hca_safety_officers')
        permitted += %i[
          investigator_name investigator_title investigator_phone
          nature_of_incident cause_of_incident root_cause
          assessment_of_future_severity_potential
          assessment_of_probability_of_recurrence
          unsafe_condition_corrected_immediately
          checklistprocedurestraining_modified
          person_responsible_for_corrective_action title
          corrective_department corrective_phone
          targeted_completion_date actual_completion_date
          osha_recordable osha_reportable reportable_injury_codes
        ]
      end

      params.require(:sheriff_safety_reporting_form).permit(permitted)
    end
  end
end
