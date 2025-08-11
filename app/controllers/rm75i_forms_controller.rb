# app/controllers/rm75i_forms_controller.rb
class Rm75iFormsController < ApplicationController
  def new
    @rm75i_form = Rm75iForm.new

    # If coming from an RM-75 event, prefill a couple fields from that form
    if params[:from_event_id].present?
      base = Rm75Form.find_by(event_id: params[:from_event_id])
      if base
        @rm75i_form.assign_attributes(
          investigator_name:  base.form_completed_by,
          investigator_phone: base.supervisor_phone
        )
      end
      @prefill_event_id = params[:from_event_id]
    end

    # Same prefill + org chain as Parking Lot / LOA
    employee_id = session[:user]&.dig("employee_id")
    @prefill_data = build_prefill_data(employee_id)

    employee   = Employee.find_by(EmployeeID: employee_id)
    unit_code  = employee&.[]("Unit")
    unit       = Unit.find_by(unit_id: unit_code)
    department = Department.find_by(department_id: unit&.department_id)
    division   = Division.find_by(division_id: department&.division_id)
    agency     = Agency.find_by(agency_id: division&.agency_id)

    @agency_options     = Agency.all.map { |a| [a.long_name, a.agency_id] }
    @division_options   = agency     ? Division.where(agency_id: agency.agency_id).map { |d| [d.long_name, d.division_id] } : []
    @department_options = division   ? Department.where(division_id: division.division_id).map { |d| [d.long_name, d.department_id] } : []
    @unit_options       = department ? Unit.where(department_id: department.department_id).map { |u| ["#{u.unit_id} - #{u.short_name}", u.unit_id] } : []

    @prefill_data[:agency]     = agency&.agency_id
    @prefill_data[:division]   = division&.division_id
    @prefill_data[:department] = department&.department_id
    @prefill_data[:unit]       = unit&.unit_id

    @form_pages = [
      { title: "Employee & Agency" },
      { title: "Investigation Details" },
      { title: "Severity & Root Cause" },
      { title: "Corrective Actions" },
      { title: "OSHA Info" }
    ]
    @form_logo = "/assets/images/default-logo.svg"
  end

  def create
    # Create or reuse Event; employee_id is NOT a column on rm75i_forms
    employee_id_for_event =
      params[:employee_id].presence || session[:user]&.dig("employee_id")

    @event =
      Event.find_by(id: params[:rm75i_form][:event_id]) ||
      Event.create!(
        event_type: "rm75i",
        employee_id: employee_id_for_event,
        event_date: Time.zone.today
      )

    @rm75i_form = Rm75iForm.new(rm75i_form_params.merge(event_id: @event.id))

    if @rm75i_form.save
      redirect_to root_path, notice: "RM-75i submitted!"
    else
      render :new
    end
  end

  private

  # Only attributes that exist on rm75i_forms
  def rm75i_form_params
    params.require(:rm75i_form).permit(
      :investigator_name, :investigator_title, :investigator_phone,
      :incident_nature, :incident_cause, :root_cause,
      :severity_potential, :recurrence_probability,
      :reportable_injury_codes,
      :corrected_immediately, :procedures_modified,
      :responsible_person, :responsible_title, :responsible_department,
      :responsible_phone, :target_completion_date, :actual_completion_date,
      :osha_recordable, :osha_reportable
    )
  end
end
