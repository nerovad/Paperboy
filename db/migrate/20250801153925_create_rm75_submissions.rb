class CreateRm75Submissions < ActiveRecord::Migration[8.0]
  def change
    create_table :rm75_submissions do |t|
      t.string :employee_id
      t.string :report_type
      t.string :bloodborne_or_covid
      t.string :employee_name
      t.string :agency
      t.string :department
      t.string :job_title
      t.string :work_hours
      t.string :hours_per_week
      t.string :supervisor_name
      t.string :supervisor_title
      t.string :supervisor_phone
      t.string :supervisor_email
      t.string :form_completed_by
      t.string :witness_name
      t.string :witness_phone
      t.date :date_of_injury
      t.string :time_of_injury
      t.date :date_employer_knew
      t.date :date_dwc1_given
      t.string :dwc1_given_by
      t.date :date_last_worked
      t.date :date_returned_to_work
      t.string :missed_work_day
      t.string :still_off_work
      t.text :injury_description
      t.string :incident_location
      t.string :on_employer_premises
      t.string :department_of_event
      t.string :equipment_used
      t.string :activity_at_time
      t.text :how_it_happened
      t.string :physician_name
      t.string :physician_address
      t.string :physician_phone
      t.string :hospital_name
      t.string :hospital_address
      t.string :hospital_phone
      t.string :hospitalized_overnight

      t.timestamps
    end
  end
end
