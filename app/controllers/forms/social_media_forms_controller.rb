# frozen_string_literal: true

module Forms
  class SocialMediaFormsController < Forms::BaseController
    # Minimal controller for the two-page template (Employee Info + Agency Info)

    def new
      @social_media_form = SocialMediaForm.new

      employee_id = session.dig(:user, 'employee_id').to_s
      @employee   = employee_id.present? ? Employee.find_by(employee_id: employee_id) : nil

      redirect_to login_path, alert: 'Please sign in to start a submission.' and return unless @employee

      unit        = Coa::Unit.resolve_for_employee(@employee)
      department  = unit ? Coa::Department.find_by(department_id: unit.department_id) : nil
      division    = department ? Coa::Division.find_by(division_id: department.division_id) : nil
      agency      = division ? Coa::Agency.find_by(agency_id: division.agency_id) : nil

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

      @social_media_form = SocialMediaForm.new(social_media_form_params)
      @social_media_form.employee_id = employee_id if @social_media_form.respond_to?(:employee_id=)

      if @social_media_form.save
        # Keep success behavior simple for the template; you can extend per form.
        redirect_to form_success_path, allow_other_host: false, status: :see_other
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

        render :new, status: :unprocessable_entity
      end
    end

    private

    def social_media_form_params
      params.require(:social_media_form).permit(
        :name, :phone, :email, :agency, :division, :department, :unit
      )
    end
  end
end
