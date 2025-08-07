class Rm75iFormsController < ApplicationController
  def new
    @rm75i_form = Rm75iForm.new

    if params[:from_event_id].present?
      base = Rm75Form.find_by(event_id: params[:from_event_id])
      if base
        @rm75i_form.assign_attributes(
          investigator_name: base.form_completed_by,
          investigator_phone: base.supervisor_phone,
          # You can map more fields here if needed
        )
      end

      @prefill_event_id = params[:from_event_id]
    end

    @form_pages = [
      { title: "Investigation Details" },
      { title: "Severity & Root Cause" },
      { title: "Corrective Actions" },
      { title: "OSHA Info" }
    ]

    @form_logo = "/assets/images/default-logo.svg"
  end

  def create
    # Ensure an Event is created or referenced
    @event = Event.find_by(id: params[:rm75i_form][:event_id]) ||
             Event.create(event_type: "rm75i", employee_id: params[:rm75i_form][:employee_id], event_date: Time.zone.today)

    @rm75i_form = Rm75iForm.new(rm75i_form_params.merge(event_id: @event.id))

    if @rm75i_form.save
      redirect_to root_path, notice: "RM-75i submitted!"
    else
      render :new
    end
  end

  private

  def rm75i_form_params
    params.require(:rm75i_form).permit(
      :investigator_name, :investigator_title, :investigator_phone,
      :osha_recordable, :osha_reportable, :incident_nature, :incident_cause,
      :root_cause, :severity_potential, :recurrence_probability,
      :reportable_injury_codes, :corrected_immediately, :procedures_modified,
      :responsible_person, :responsible_title, :responsible_department,
      :responsible_phone, :target_completion_date, :actual_completion_date,
      :employee_id # used for event creation fallback
    )
  end
end
