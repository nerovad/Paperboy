# frozen_string_literal: true

module Forms
  class CriticalInformationReportingsController < Forms::BaseController
    # Minimal controller for the two-page template (Employee Info + Agency Info)

    def new
      @critical_information_reporting = CriticalInformationReporting.new

      employee_id = session.dig(:user, 'employee_id').to_s
      @employee   = employee_id.present? ? Employee.find_by(employee_id: employee_id) : nil

      redirect_to login_path, alert: 'Please sign in to start a submission.' and return unless @employee

      # --- Organization chain (same pattern you use now) ---
      unit        = Coa::Unit.resolve_for_employee(@employee)
      department  = unit ? Coa::Department.find_by(department_id: unit.department_id) : nil
      division    = department ? Coa::Division.find_by(division_id: department.division_id) : nil
      agency      = division ? Coa::Agency.find_by(agency_id: division.agency_id) : nil

      # --- Prefill values (everything prefilled exactly like you do now) ---
      @prefill_data = {
        employee_id: @employee.employee_id,
        name: [@employee.first_name, @employee.last_name].compact.join(' '),
        phone: @employee.work_phone,
        email: @employee.email,
        agency: agency&.agency_id,
        division: division&.division_id,
        department: department&.department_id,
        unit: unit&.unit_id
      }

      # --- Select options (IDs/order match gsabss_selects_controller.js expectations) ---
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

      # Unit label = "unit_id - long_name", value = unit_id (your current pattern)
      @unit_options = if department
                        Coa::Unit.where(department_id: department.department_id)
                                 .order(:unit_id)
                                 .map { |u| ["#{u.unit_id} - #{u.long_name}", u.unit_id] }
                      else
                        []
                      end

      # Employee dropdown options (for Pages 4+) — scoped to General Services Agency
      gsa = Coa::Agency.find_by(long_name: 'General Services Agency')
      @employee_options = Employee.where(agency: gsa&.agency_id)
                                  .select(:employee_id, :first_name, :last_name)
                                  .order(:last_name, :first_name)
                                  .map { |e| ["#{e.first_name} #{e.last_name}", e.employee_id] }

      # Agency options for Impacted Customers multi-select
      @impacted_customer_options = Coa::Agency.order(:long_name).pluck(:long_name, :agency_id)

      # Load location options
      @location_options = load_location_options
    end

    def show
      @critical_information_reporting = CriticalInformationReporting.includes(:status_changes).find(params[:id])
      @status_changes = @critical_information_reporting.status_changes.chronological
    end

    def pdf
      @critical_information_reporting = CriticalInformationReporting.find(params[:id])
      pdf_data = CriticalInformationPdfGenerator.generate(@critical_information_reporting)

      send_data pdf_data,
                filename: "CriticalInformationReport_#{@critical_information_reporting.id}.pdf",
                type: 'application/pdf',
                disposition: 'attachment'
    end

    def download_media
      @critical_information_reporting = CriticalInformationReporting.find(params[:id])
      attachment = @critical_information_reporting.media_photo_pdf_etc.find_by(id: params[:attachment_id])

      if attachment
        redirect_to rails_blob_path(attachment, disposition: 'attachment')
      else
        redirect_to inbox_queue_path, alert: 'No media attachment found.'
      end
    end

    def edit
      @critical_information_reporting = CriticalInformationReporting.find(params[:id])

      employee_id = session.dig(:user, 'employee_id').to_s
      @employee = employee_id.present? ? Employee.find_by(employee_id: employee_id) : nil

      redirect_to login_path, alert: 'Please sign in.' and return unless @employee

      # Load organization options (same as new action)
      @agency_options = Coa::Agency.order(:long_name).pluck(:long_name, :agency_id)

      agency = Coa::Agency.find_by(agency_id: @critical_information_reporting.agency)
      @division_options = agency ? Coa::Division.where(agency_id: agency.agency_id).order(:long_name).pluck(:long_name, :division_id) : []

      division = Coa::Division.find_by(division_id: @critical_information_reporting.division)
      @department_options = division ? Coa::Department.where(division_id: division.division_id).order(:long_name).pluck(:long_name, :department_id) : []

      department = Coa::Department.find_by(department_id: @critical_information_reporting.department)
      @unit_options = if department
                        Coa::Unit.where(department_id: department.department_id)
                                 .order(:unit_id)
                                 .map { |u| ["#{u.unit_id} - #{u.long_name}", u.unit_id] }
                      else
                        []
                      end

      gsa = Coa::Agency.find_by(long_name: 'General Services Agency')
      @employee_options = Employee.where(agency: gsa&.agency_id)
                                  .select(:employee_id, :first_name, :last_name)
                                  .order(:last_name, :first_name)
                                  .map { |e| ["#{e.first_name} #{e.last_name}", e.employee_id] }

      @impacted_customer_options = Coa::Agency.order(:long_name).pluck(:long_name, :agency_id)

      @location_options = load_location_options
    end

    def update
      @critical_information_reporting = CriticalInformationReporting.find(params[:id])

      if @critical_information_reporting.update(critical_information_reporting_params)
        redirect_to form_success_path, notice: 'Form submitted and routed for approval.', allow_other_host: false, status: :see_other
      else
        # Reload options on failure
        @agency_options = Coa::Agency.order(:long_name).pluck(:long_name, :agency_id)

        agency = Coa::Agency.find_by(agency_id: @critical_information_reporting.agency)
        @division_options = agency ? Coa::Division.where(agency_id: agency.agency_id).order(:long_name).pluck(:long_name, :division_id) : []

        division = Coa::Division.find_by(division_id: @critical_information_reporting.division)
        @department_options = division ? Coa::Department.where(division_id: division.division_id).order(:long_name).pluck(:long_name, :department_id) : []

        department = Coa::Department.find_by(department_id: @critical_information_reporting.department)
        @unit_options = if department
                          Coa::Unit.where(department_id: department.department_id)
                                   .order(:unit_id)
                                   .map { |u| ["#{u.unit_id} - #{u.long_name}", u.unit_id] }
                        else
                          []
                        end

        gsa = Coa::Agency.find_by(long_name: 'General Services Agency')
        @employee_options = Employee.where(agency: gsa&.agency_id)
                                    .select(:employee_id, :first_name, :last_name)
                                    .order(:last_name, :first_name)
                                    .map { |e| ["#{e.first_name} #{e.last_name}", e.employee_id] }

        @impacted_customer_options = Coa::Agency.order(:long_name).pluck(:long_name, :agency_id)

        @location_options = load_location_options

        render :edit, status: :unprocessable_entity
      end
    end

    def update_status
      @critical_information_reporting = CriticalInformationReporting.find(params[:id])
      new_status = params[:status]

      if CriticalInformationReporting.statuses.keys.include?(new_status)
        @critical_information_reporting.update!(status: new_status)

        redirect_to inbox_queue_path, notice: "Critical Information Report status updated to #{new_status.titleize}."
      else
        redirect_to inbox_queue_path, alert: 'Invalid status.'
      end
    end

    def approve
      @critical_information_reporting = CriticalInformationReporting.find(params[:id])

      @critical_information_reporting.update!(status: :resolved)

      redirect_to inbox_queue_path, notice: 'Critical Information Report marked as resolved.'
    end

    def deny
      @critical_information_reporting = CriticalInformationReporting.find(params[:id])

      params[:denial_reason].to_s.strip

      @critical_information_reporting.update!(status: :cancelled)

      redirect_to inbox_queue_path, alert: 'Critical Information Report cancelled.'
    end

    def create
      employee      = session[:user]
      employee_id   = employee&.dig('employee_id').to_s

      permitted = critical_information_reporting_params
      Rails.logger.info "[CIR CREATE] Raw params keys: #{params[:critical_information_reporting]&.keys}"
      Rails.logger.info "[CIR CREATE] Permitted params: #{permitted.to_h}"

      @critical_information_reporting = CriticalInformationReporting.new(permitted)
      @critical_information_reporting.employee_id = employee_id if @critical_information_reporting.respond_to?(:employee_id=)

      if @critical_information_reporting.save
        # ROUTING_BLOCK_START
        NotifyTeamsJob.perform_later(@critical_information_reporting.id)
        redirect_to form_success_path, notice: 'Form submitted and routed for approval.', allow_other_host: false, status: :see_other
        # ROUTING_BLOCK_END
      else
        Rails.logger.warn "[CIR CREATE] Validation failed: #{@critical_information_reporting.errors.full_messages}"
        Rails.logger.warn "[CIR CREATE] Attribute values: #{@critical_information_reporting.attributes.select { |_k, v| v.present? }.keys}"
        # Rebuild options on failure (same as in new)
        # (We intentionally repeat the logic to keep this template self-contained.)
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
          unit: unit&.unit_id
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

        # CRITICAL: Reload employee and location options for Pages 4+ when validation fails
        gsa = Coa::Agency.find_by(long_name: 'General Services Agency')
        @employee_options = Employee.where(agency: gsa&.agency_id)
                                    .select(:employee_id, :first_name, :last_name)
                                    .order(:last_name, :first_name)
                                    .map { |e| ["#{e.first_name} #{e.last_name}", e.employee_id] }

        @impacted_customer_options = Coa::Agency.order(:long_name).pluck(:long_name, :agency_id)

        @location_options = load_location_options

        render :new, status: :unprocessable_entity
      end
    end

    def download_media_photo_pdf_etc
      attachment = @critical_information_reporting.media_photo_pdf_etc.find(params[:attachment_id])
      redirect_to rails_blob_path(attachment, disposition: 'attachment')
    end

    private

    def critical_information_reporting_params
      raw = params.require(:critical_information_reporting).permit(
        :employee_id, :name, :phone, :email,
        :agency, :division, :department, :unit,
        :incident_type, :incident_details, :cause,
        :impact_started, :location,
        :urgency,
        :impact, :next_steps,
        :other_building,
        staff_involved: [],
        impacted_customers: [],
        building: [],
        impacted_agency: [],
        impacted_employee: [],
        media_photo_pdf_etc: []
      )

      # Normalize multi-select arrays into comma-separated strings
      raw[:staff_involved] = Array(raw[:staff_involved]).reject(&:blank?).join(',')
      raw[:impacted_customers] = Array(raw[:impacted_customers]).reject(&:blank?).join(',')
      raw[:building] = Array(raw[:building]).reject(&:blank?).join(',')
      raw[:impacted_agency] = Array(raw[:impacted_agency]).reject(&:blank?).join(',')
      raw[:impacted_employee] = Array(raw[:impacted_employee]).reject(&:blank?).join(',')

      raw
    end

    # The catalogue lives in CriticalInformationLocation; the manager covering
    # each site comes from the CIR authorization console, so a routing change
    # made there shows up in this dropdown on the next render.
    def load_location_options
      manager_names = CriticalInformationLocationRouter.manager_names_by_location

      CriticalInformationLocation::ALL.map do |location|
        name = manager_names[location]
        [name.present? ? "#{location} - #{name}" : location, location]
      end
    end
  end
end
