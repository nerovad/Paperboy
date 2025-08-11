# app/controllers/rm75_forms_controller.rb
class Rm75FormsController < ApplicationController
  def new
    @rm75_form = Rm75Form.new

    employee_id = session[:user]&.dig("employee_id")
    @prefill_data = build_prefill_data(employee_id)

    # Org dropdowns (same pattern as Parking Lot / LOA)
    employee   = Employee.find_by(EmployeeID: employee_id)
    unit_code  = employee&.[]("Unit")
    unit       = Unit.find_by(unit_id: unit_code)
    department = Department.find_by(department_id: unit&.department_id)
    division   = Division.find_by(division_id: department&.division_id)
    agency     = Agency.find_by(agency_id: division&.agency_id)

    @agency_options = Agency.all.map { |a| [a.long_name, a.agency_id] }
    @division_options = agency ? Division.where(agency_id: agency.agency_id).map { |d| [d.long_name, d.division_id] } : []
    @department_options = division ? Department.where(division_id: division.division_id).map { |d| [d.long_name, d.department_id] } : []
    @unit_options = department ? Unit.where(department_id: department.department_id).map { |u| ["#{u.unit_id} - #{u.short_name}", u.unit_id] } : []

    # Selected IDs for first render
    @prefill_data[:agency]     = agency&.agency_id
    @prefill_data[:division]   = division&.division_id
    @prefill_data[:department] = department&.department_id
    @prefill_data[:unit]       = unit&.unit_id

    @form_pages = [
      { title: "Injured Employee Info" },
      { title: "Agency Info" },
      { title: "Incident Dates and Status" },
      { title: "Incident Description" },
      { title: "Medical Info" }
    ]
    @form_logo = "/assets/images/default-logo.svg"
  end

  def create
    # employee_id is NOT a column on rm75_forms; read it from top-level param
    employee_id_for_event = params[:employee_id].presence || session[:user]&.dig("employee_id")

    @event = Event.create!(
      event_type: "rm75",
      employee_id: employee_id_for_event,
      event_date: params[:rm75_form][:date_of_injury].presence || Time.zone.now
    )

    @rm75_form = Rm75Form.new(rm75_form_params.merge(event_id: @event.id))

    if @rm75_form.save
      redirect_to root_path, notice: "RM-75 submitted!"
    else
      render :new
    end
  end

  private

  def rm75_form_params
    # ONLY columns that exist on rm75_forms (per our migration)
    params.require(:rm75_form).permit(
      :report_type,
      :bloodborne_pathogen,
      :job_title, :work_hours, :hours_per_week,
      :supervisor_name, :supervisor_title, :supervisor_phone, :supervisor_email,
      :form_completed_by,
      :date_of_injury, :time_of_injury,
      :injury_description,
      :date_last_worked, :date_returned_to_work,
      :location_of_event, :on_employers_premises, :department_of_exposure,
      :equipment_in_use, :specific_activity, :injury_sequence,
      :physician_name, :physician_address, :physician_phone,
      :hospital_name, :hospital_address, :hospital_phone, :hospitalized_overnight
    )
  end
end
