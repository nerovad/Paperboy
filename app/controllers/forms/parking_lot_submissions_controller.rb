# frozen_string_literal: true

# app/controllers/forms/parking_lot_submissions_controller.rb
module Forms
  class ParkingLotSubmissionsController < Forms::BaseController
    before_action :set_parking_lot_submission, only: %i[show pdf approve deny]

    # Permit types offered on each vehicle row. 'R Lot' is restricted to MB3
    # union members and is filtered out of the dropdown for everyone else.
    PERMIT_TYPES = ['Carpool', 'Courier', 'Grand Jury Parking', 'Loading Docks',
                    'Maintenance', 'R Lot', 'Traffic Circle', 'Other'].freeze
    MB3_ONLY_PERMIT_TYPES = ['R Lot'].freeze

    def new
      @parking_lot_submission = ParkingLotSubmission.new
      @parking_lot_submission.parking_lot_vehicles.build

      # Safely read session
      employee_id = session.dig(:user, 'employee_id').to_s
      @employee   = employee_id.present? ? Employee.find_by(employee_id: employee_id) : nil

      unless @employee
        redirect_to login_path, alert: 'Please sign in to start a submission.' and return

        @agency_options     = Coa::Agency.order(:long_name).pluck(:long_name, :agency_id)
        @division_options   = []
        @department_options = []
        @unit_options       = []
        return
      end

      # MB3 flag — union codes live in the Paperboy-owned employee_union_codes
      # table, not on the GSABSS Employees record. Defaults to non-MB3 when unset.
      @is_mb3 = EmployeeUnionCode.code_for(@employee.employee_id) == 'MB3'

      # Org lookups (guard each step)
      unit        = Coa::Unit.resolve_for_employee(@employee)
      department  = unit ? Coa::Department.find_by(department_id: unit.department_id) : nil
      division    = department ? Coa::Division.find_by(division_id: department.division_id) : nil
      agency      = division ? Coa::Agency.find_by(agency_id: division.agency_id) : nil

      # Prefill with IDs (unit = ID only)
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

      # Permit types (R Lot is MB3-only)
      @permit_type_options = permit_type_options(@is_mb3)

      # Dropdowns
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
      employee_id   = employee['employee_id'].to_s

      # Check Union Code from DB (trust server-side). Sourced from the Paperboy-owned
      # employee_union_codes table; defaults to non-MB3 when no code is recorded.
      emp_record = Employee.find_by(employee_id: employee_id)
      is_mb3 = (EmployeeUnionCode.code_for(employee_id) == 'MB3')

      # Get employee's department for authorized approver lookup
      unit = Coa::Unit.resolve_for_employee(emp_record)
      department = unit ? Coa::Department.find_by(department_id: unit.department_id) : nil

      # Build the submission early so we can access the submitted unit
      @parking_lot_submission = ParkingLotSubmission.new(parking_lot_submission_params)
      @parking_lot_submission.employee_id = employee_id
      submitted_unit = @parking_lot_submission.unit

      # R Lot is limited to MB3 union members and is not offered to anyone else,
      # so a non-MB3 request carrying it did not come from the rendered form.
      if !is_mb3 && mb3_only_permit_types_requested?
        @parking_lot_submission.errors.add(:base, 'R Lot permits are limited to MB3 union members.')
        render_new_with_options(emp_record, is_mb3) and return
      end

      # Non-MB3 submitters route through the Authorization step (step 1): block here
      # if no one holds the Parking Permits authorization for their budget unit, so
      # the request never routes into a dead end. MB3 employees skip that step.
      unless is_mb3
        authorized_approvers = if department && submitted_unit.present?
                                 AuthorizedApprover.approver_for_unit(
                                   department_id: department.department_id,
                                   service_type: 'P',
                                   unit_id: submitted_unit
                                 )
                               else
                                 []
                               end

        if authorized_approvers.empty?
          @parking_lot_submission.errors.add(:base, "No authorized approver found for Parking Permits in your budget unit. Please contact your department's authorization manager.")
          render_new_with_options(emp_record, is_mb3) and return
        end
      end

      if @parking_lot_submission.save
        # Routing is defined in the form builder (Authorization -> Sean Payne ->
        # GSA_Security) and executed by TrackableStatus. MB3 employees skip the
        # authorization step and enter at the next step.
        @parking_lot_submission.start_approval!(skip_types: is_mb3 ? ['authorization'] : [])
        redirect_to form_success_path, allow_other_host: false, status: :see_other
      else
        render_new_with_options(emp_record, is_mb3)
      end
    end

    # READ-ONLY SHOW (uses your shared partial in the view)
    def show; end

    def pdf
      # @parking_lot_submission is already set by before_action
      pdf_data = ParkingLotPdfGenerator.generate(@parking_lot_submission)

      send_data pdf_data,
                filename: "ParkingLotSubmission_#{@parking_lot_submission.id}.pdf",
                type: 'application/pdf',
                disposition: 'inline'
    end

    def approve
      # @parking_lot_submission set by before_action. Routing is driven by the
      # form-builder steps via TrackableStatus; advance to the next matching step
      # (or finalize as approved).
      actor = session.dig(:user, 'employee_id').to_s
      @parking_lot_submission.advance_approval!

      if @parking_lot_submission.approved?
        @parking_lot_submission.update_columns(approved_by: actor, approved_at: Time.current)
        notice = 'Request approved.'
      else
        notice = 'Approved and routed to the next step.'
      end

      redirect_to inbox_queue_path, notice: notice
    end

    def deny
      reason = params[:denial_reason].to_s.strip
      @parking_lot_submission.assign_attributes(
        denial_reason: reason.presence || 'No reason provided',
        denied_by: session.dig(:user, 'employee_id').to_s,
        denied_at: Time.current
      )
      @parking_lot_submission.denied!

      # Notify the submitter of the denial + reason (in-app routing handles approvers).
      SecurityMailer.denied(@parking_lot_submission).deliver_later

      redirect_to inbox_queue_path, alert: 'Parking request denied.'
    end

    def index
      # If you intend to always redirect to inbox, do it and return to avoid extra work below
      redirect_to inbox_queue_path and return

      employee = session[:user]

      if employee.present? && employee['employee_id'].present?
        Rails.logger.info "Logged in as employee #{employee['employee_id']}"

        @pending_submissions = ParkingLotSubmission
                               .where(supervisor_id: employee['employee_id'].to_s)
                               .where(status: 'in_progress')
                               .order(created_at: :desc)
      else
        Rails.logger.warn 'No logged-in employee found'
        @pending_submissions = []
      end
    end

    private

    def set_parking_lot_submission
      @parking_lot_submission = ParkingLotSubmission.find(params[:id])
    end

    # Non-MB3 submitters never see the MB3-only options in the dropdown.
    def permit_type_options(is_mb3)
      is_mb3 ? PERMIT_TYPES : PERMIT_TYPES - MB3_ONLY_PERMIT_TYPES
    end

    # The dropdown is filtered client-side, so re-check the submitted values
    # server-side before saving.
    def mb3_only_permit_types_requested?
      @parking_lot_submission.parking_lot_vehicles.any? do |vehicle|
        Array(vehicle.permit_type).intersect?(MB3_ONLY_PERMIT_TYPES)
      end
    end

    # Rebuild the option ivars and re-render the new form on a failed create.
    def render_new_with_options(emp_record, is_mb3)
      @is_mb3 = is_mb3
      @permit_type_options = permit_type_options(is_mb3)
      reload_form_options(emp_record)
      render :new, status: :unprocessable_entity
    end

    def reload_form_options(emp_record)
      unit       = Coa::Unit.resolve_for_employee(emp_record)
      department = unit ? Coa::Department.find_by(department_id: unit.department_id) : nil
      division   = department ? Coa::Division.find_by(division_id: department.division_id) : nil
      agency     = division ? Coa::Agency.find_by(agency_id: division.agency_id) : nil

      @agency_options     = Coa::Agency.order(:long_name).pluck(:long_name, :agency_id)
      @division_options   = division ? Coa::Division.where(agency_id: agency&.agency_id).order(:long_name).pluck(:long_name, :division_id) : []
      @department_options = department ? Coa::Department.where(division_id: division&.division_id).order(:long_name).pluck(:long_name, :department_id) : []
      @unit_options       = department ? Coa::Unit.where(department_id: department.department_id).order(:unit_id).map { |u| ["#{u.unit_id} - #{u.long_name}", u.unit_id] } : []
    end

    def parking_lot_submission_params
      # NOTE: Do NOT permit :status or :employee_id from the form (we set both server-side)
      params.require(:parking_lot_submission).permit(
        :name,
        :phone,
        :email,
        :agency,
        :division,
        :department,
        :unit,
        parking_lot_vehicles_attributes: [
          :id,
          :make,
          :model,
          :color,
          :year,
          :license_plate,
          :other_permit_type,
          :_destroy,
          { permit_type: [], carpool_participants: [] }
        ]
      )
    end
  end
end
