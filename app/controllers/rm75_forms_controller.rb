class Rm75FormsController < ApplicationController
  def new
    @event = Event.new(event_type: "rm75")
    @rm75_form = Rm75Form.new

    @form_pages = [
      { title: "Injured Employee Info" },
      { title: "Supervisor and Witness Info" },
      { title: "Incident Dates and Status" },
      { title: "Incident Description" },
      { title: "Medical Info" }
    ]

    @form_logo = "/assets/images/default-logo.svg"
  end

  def create
    # First create the event
    @event = Event.new(
      event_type: "rm75",
      employee_id: params[:rm75_form][:employee_id],
      event_date: params[:rm75_form][:date_of_injury] || Time.zone.now
    )

    if @event.save
      @rm75_form = Rm75Form.new(rm75_form_params.merge(event_id: @event.id))

      if @rm75_form.save
        redirect_to root_path, notice: "RM-75 submitted!"
      else
        render :new
      end
    else
      render :new
    end
  end

  private

  def rm75_form_params
    params.require(:rm75_form).permit(
      :report_type, :bloodborne_pathogen, :job_title, :work_hours,
      :hours_per_week, :supervisor_name, :supervisor_title, :supervisor_email,
      :supervisor_phone, :form_completed_by, :date_of_injury, :time_of_injury,
      :injury_description, :date_last_worked, :date_returned_to_work,
      :location_of_event, :on_employers_premises, :department_of_exposure,
      :equipment_in_use, :specific_activity, :injury_sequence, :physician_name,
      :physician_address, :physician_phone, :hospital_name, :hospital_address,
      :hospital_phone, :hospitalized_overnight
    )
  end
end
