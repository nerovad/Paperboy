class Rm75iSubmissionsController < ApplicationController
  def new
    @rm75i_submission = Rm75iSubmission.new

    if params[:from_rm75_id].present?
      base = Rm75Submission.find_by(id: params[:from_rm75_id])
      if base
        @rm75i_submission.assign_attributes(
          employee_id: base.employee_id,
          employee_name: base.employee_name,
          department: base.department,
          job_title: base.job_title,
          division: base.try(:division),
          work_hours: base.work_hours,
          hours_per_week: base.hours_per_week,
          supervisor_name: base.supervisor_name,
          supervisor_title: base.supervisor_title,
          supervisor_phone: base.supervisor_phone,
          supervisor_email: base.supervisor_email,
          form_completed_by: base.form_completed_by,
          date_of_injury: base.date_of_injury,
          time_occurred: base.time_of_injury,
          incident_location: base.incident_location,
          injury_description: base.injury_description,
          how_it_happened: base.how_it_happened,
          physician_name: base.physician_name,
          physician_address: base.physician_address,
          physician_phone: base.physician_phone,
          hospital_name: base.hospital_name,
          hospital_address: base.hospital_address,
          hospital_phone: base.hospital_phone,
          hospitalized_overnight: base.hospitalized_overnight,
          agency: base.agency,
          bloodborne_or_covid: base.bloodborne_or_covid
        )
      end
    end
  end

  def create
    @rm75i_submission = Rm75iSubmission.new(rm75i_submission_params)
    if @rm75i_submission.save
      redirect_to root_path, notice: "RM-75i submitted!"
    else
      render :new
    end
  end

  private

  def rm75i_submission_params
    Rm75iSubmission.column_names.map(&:to_sym)
  end
end
