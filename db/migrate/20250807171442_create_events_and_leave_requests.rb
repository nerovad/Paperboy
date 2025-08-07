class CreateEventsAndLeaveRequests < ActiveRecord::Migration[8.0]
  def change
    # EVENTS
    create_table :events do |t|
      t.string :event_type, null: false
      t.string :subtype
      t.integer :employee_id, null: false
      t.integer :reported_by_id
      t.datetime :event_date, null: false
      t.string :location
      t.boolean :on_premises
      t.text :initial_summary
      t.date :date_reported
      t.date :date_resolved
      t.string :status, default: "open"
      t.timestamps
    end

    add_foreign_key :events, :employees, column: :employee_id, primary_key: "EmployeeID"
    add_foreign_key :events, :employees, column: :reported_by_id, primary_key: "EmployeeID"

    # RM75 FORM
    create_table :rm75_forms do |t|
      t.references :event, null: false, foreign_key: true
      t.string :report_type
      t.boolean :bloodborne_pathogen
      t.string :job_title
      t.string :work_hours
      t.integer :hours_per_week
      t.string :supervisor_name
      t.string :supervisor_title
      t.string :supervisor_email
      t.string :supervisor_phone
      t.string :form_completed_by
      t.date :date_of_injury
      t.time :time_of_injury
      t.text :injury_description
      t.date :date_last_worked
      t.date :date_returned_to_work
      t.string :location_of_event
      t.boolean :on_employers_premises
      t.string :department_of_exposure
      t.text :equipment_in_use
      t.text :specific_activity
      t.text :injury_sequence
      t.string :physician_name
      t.string :physician_address
      t.string :physician_phone
      t.string :hospital_name
      t.string :hospital_address
      t.string :hospital_phone
      t.boolean :hospitalized_overnight
      t.timestamps
    end

    # RM75I FORM
    create_table :rm75i_forms do |t|
      t.references :event, null: false, foreign_key: true
      t.string :investigator_name
      t.string :investigator_title
      t.string :investigator_phone
      t.boolean :osha_recordable
      t.boolean :osha_reportable
      t.text :incident_nature
      t.text :incident_cause
      t.text :root_cause
      t.string :severity_potential
      t.string :recurrence_probability
      t.text :reportable_injury_codes
      t.boolean :corrected_immediately
      t.boolean :procedures_modified
      t.string :responsible_person
      t.string :responsible_title
      t.string :responsible_department
      t.string :responsible_phone
      t.date :target_completion_date
      t.date :actual_completion_date
      t.timestamps
    end

    # OSHA 301 FORM
    create_table :osha_301_forms do |t|
      t.references :event, null: false, foreign_key: true
      t.string :physician_name
      t.string :treatment_location
      t.boolean :treated_in_er
      t.boolean :hospitalized_overnight
      t.string :case_number
      t.date :date_of_injury
      t.time :time_began_work
      t.time :time_of_event
      t.text :activity_before_incident
      t.text :incident_description
      t.text :injury_type
      t.text :harmful_object
      t.string :completed_by
      t.string :completed_by_title
      t.string :completed_by_phone
      t.date :completion_date
      t.timestamps
    end

    # LOA FORM
    create_table :loa_forms do |t|
      t.references :event, null: false, foreign_key: true
      t.date :last_date_worked
      t.date :leave_start_date
      t.date :leave_end_date
      t.boolean :extension_requested
      t.text :requested_during_leave
      t.boolean :applying_for_disability
      t.string :leave_type
      t.text :leave_reason
      t.string :emp_initials_1
      t.date :initial_date_1
      t.string :biweekly_hours
      t.string :pay_status_during_leave
      t.text :estimated_leave_balances
      t.text :expected_disability_benefits
      t.text :notes_1
      t.boolean :agreed_to_terms
      t.string :emp_initials_2
      t.date :initial_date_2
      t.date :waive_benefits_start_date
      t.date :waive_benefits_end_date
      t.text :waived_sources
      t.string :emp_initials_3
      t.date :initial_date_3
      t.boolean :employee_verified_info
      t.text :notes_2
      t.string :request_status
      t.string :team_signature
      t.string :sig_employee_id
      t.date :sig_date
      t.timestamps
    end
  end
end
