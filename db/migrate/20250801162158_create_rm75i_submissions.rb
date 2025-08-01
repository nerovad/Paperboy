class CreateRm75iSubmissions < ActiveRecord::Migration[8.0]
  def change
    create_table :rm75i_submissions do |t|
      t.string :employee_id
      t.string :report_type
      t.string :employee_name
      t.string :department
      t.string :job_title
      t.string :division
      t.string :work_hours
      t.string :hours_per_week
      t.string :supervisor_name
      t.string :supervisor_title
      t.string :supervisor_phone
      t.string :supervisor_email
      t.string :form_completed_by
      t.date :date_of_injury
      t.string :time_occurred
      t.string :incident_location
      t.text :injury_description
      t.text :how_it_happened
      t.string :physician_name
      t.string :physician_address
      t.string :physician_phone
      t.string :hospital_name
      t.string :hospital_address
      t.string :hospital_phone
      t.string :hospitalized_overnight
      t.string :agency
      t.string :bloodborne_or_covid
      t.string :source_blood_tested
      t.string :mr_number_source
      t.string :mr_number_employee
      t.string :covid_status
      t.date :date_investigation_began
      t.date :date_investigation_complete
      t.string :investigator_name
      t.string :investigator_title
      t.string :investigator_phone
      t.text :nature_of_incident
      t.text :cause_of_incident
      t.text :root_cause
      t.string :future_severity
      t.string :recurrence_probability
      t.string :unsafe_corrected_immediately
      t.string :checklist_or_training_updated
      t.date :actual_correction_date
      t.date :targeted_correction_date
      t.string :correction_responsible
      t.string :correction_title
      t.string :correction_dept
      t.string :correction_phone
      t.string :injury_code
      t.string :osha_reportable
      t.string :osha_recordable
      t.text :no_correction_notes
      t.string :job_classification
      t.string :compensation
      t.string :home_phone
      t.date :date_of_hire
      t.date :dob
      t.string :email
      t.string :work_phone
      t.string :cell_phone
      t.string :city
      t.string :state
      t.string :zip
      t.string :ssn
      t.string :home_address
      t.string :ethnicity
      t.string :unit_number

      t.timestamps
    end
  end
end
