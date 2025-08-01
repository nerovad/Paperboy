class Rm75SubmissionsController < ApplicationController
  def new
    @rm75_submission = Rm75Submission.new

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
    @rm75_submission = Rm75Submission.new(rm75_submission_params)
    if @rm75_submission.save
      redirect_to root_path, notice: "RM-75 submitted!"
    else
      render :new
    end
  end

  private

  def rm75_submission_params
    params.require(:rm75_submission).permit(
      :employee_id, :report_type, :bloodborne_or_covid, :employee_name, :agency,
      :department, :job_title, :work_hours, :hours_per_week, :supervisor_name,
      :supervisor_title, :supervisor_phone, :supervisor_email, :form_completed_by,
      :witness_name, :witness_phone, :date_of_injury, :time_of_injury, :date_employer_knew,
      :date_dwc1_given, :dwc1_given_by, :date_last_worked, :date_returned_to_work,
      :missed_work_day, :still_off_work, :injury_description, :incident_location,
      :on_employer_premises, :department_of_event, :equipment_used, :activity_at_time,
      :how_it_happened, :physician_name, :physician_address, :physician_phone,
      :hospital_name, :hospital_address, :hospital_phone, :hospitalized_overnight
    )
  end
end
