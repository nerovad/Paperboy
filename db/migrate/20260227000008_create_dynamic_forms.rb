class CreateDynamicForms < ActiveRecord::Migration[8.0]
  def change
    # Carpool Forms
    create_table :carpool_forms do |t|
      t.string :employee_id
      t.string :name
      t.string :phone
      t.string :email
      t.string :agency
      t.string :division
      t.string :department
      t.string :unit
      t.integer :status, default: 0
      t.timestamps
    end

    # Gym Locker Forms
    create_table :gym_locker_forms do |t|
      t.string :employee_id
      t.string :name
      t.string :phone
      t.string :email
      t.string :agency
      t.string :division
      t.string :department
      t.string :unit
      t.integer :status, default: 0
      t.timestamps
    end

    # Social Media Forms
    create_table :social_media_forms do |t|
      t.string :employee_id
      t.string :name
      t.string :phone
      t.string :email
      t.string :agency
      t.string :division
      t.string :department
      t.string :unit
      t.integer :status, default: 0
      t.timestamps
    end

    # Brown Mail Forms
    create_table :brown_mail_forms do |t|
      t.string :employee_id
      t.string :name
      t.string :phone
      t.string :email
      t.string :agency
      t.string :division
      t.string :department
      t.string :unit
      t.integer :status, default: 0
      t.timestamps
    end

    # Leave of Absence Forms
    create_table :leave_of_absence_forms do |t|
      t.string :employee_id
      t.string :name
      t.string :phone
      t.string :email
      t.string :agency
      t.string :division
      t.string :department
      t.string :unit
      t.integer :status, default: 0
      t.string :approver_id
      t.text :deny_reason
      t.timestamps
    end
    add_index :leave_of_absence_forms, :employee_id
    add_index :leave_of_absence_forms, :approver_id

    # Work Schedule or Location Update Forms
    create_table :work_schedule_or_location_update_forms do |t|
      t.string :employee_id
      t.string :name
      t.string :phone
      t.string :email
      t.string :agency
      t.string :division
      t.string :department
      t.string :unit
      t.integer :status, default: 0
      t.string :approver_id
      t.text :deny_reason
      t.timestamps
    end
    add_index :work_schedule_or_location_update_forms, :employee_id
    add_index :work_schedule_or_location_update_forms, :approver_id

    # Workplace Violence Forms
    create_table :workplace_violence_forms do |t|
      t.string :employee_id
      t.string :name
      t.string :phone
      t.string :email
      t.string :agency
      t.string :division
      t.string :department
      t.string :unit
      t.integer :status, default: 0
      t.string :approver_id
      t.text :deny_reason
      t.timestamps
    end
    add_index :workplace_violence_forms, :employee_id
    add_index :workplace_violence_forms, :approver_id

    # Notice of Change Forms
    create_table :notice_of_change_forms do |t|
      t.string :employee_id
      t.string :name
      t.string :phone
      t.string :email
      t.string :agency
      t.string :division
      t.string :department
      t.string :unit
      t.integer :status, default: 0
      t.string :approver_id
      t.text :deny_reason
      t.timestamps
    end
    add_index :notice_of_change_forms, :employee_id
    add_index :notice_of_change_forms, :approver_id

    # OSHA 301 Forms
    create_table :osha301_forms do |t|
      t.string :employee_id
      t.string :name
      t.string :phone
      t.string :email
      t.string :agency
      t.string :division
      t.string :department
      t.string :unit
      t.integer :status, default: 0
      t.string :approver_id
      t.text :deny_reason
      t.bigint :rm75_form_id
      t.string :street
      t.string :city
      t.string :state
      t.string :zip
      t.datetime :date_of_birth
      t.datetime :date_hired
      t.string :sex
      t.string :name_of_physician_or_other_health_care_professional
      t.string :was_treatment_given_away_from_the_worksite
      t.string :facility_name
      t.string :facility_street_address
      t.string :facility_city
      t.string :facility_state
      t.string :facility_zip
      t.string :was_the_employee_treated_in_an_emergency_room
      t.string :was_the_employee_hospitalized_overnight_as_an_inpatient
      t.string :case_number_from_the_log
      t.datetime :date_of_injury_or_illness
      t.datetime :time_employee_began_work
      t.datetime :time_of_event
      t.text :what_happened_tell_us_how_the_injury_occurred
      t.text :what_was_the_injury_or_illness
      t.text :what_was_the_employee_doing_just_before_the_incident_occurred
      t.text :what_object_or_substance_directly_harmed_the_employee
      t.string :did_employee_die
      t.datetime :date_of_death
      t.timestamps
    end
    add_index :osha301_forms, :employee_id
    add_index :osha301_forms, :approver_id
    add_index :osha301_forms, :rm75_form_id

    # RM75 Forms
    create_table :rm75_forms do |t|
      t.string :employee_id
      t.string :name
      t.string :phone
      t.string :email
      t.string :agency
      t.string :division
      t.string :department
      t.string :unit
      t.integer :status, default: 0
      t.string :approver_id
      t.text :deny_reason
      t.string :report_type
      t.string :bloodborne_pathogen_exposure
      t.string :supervisor_name
      t.string :witness_name
      t.string :witness_phone
      t.datetime :date_of_injury_or_illness
      t.datetime :date_employer_notified
      t.datetime :date_dwc1_given
      t.string :who_gave_the_dwc1
      t.datetime :date_last_worked
      t.datetime :date_returned_to_work
      t.string :missed_full_work_day_
      t.string :still_off_work
      t.text :specific_injury_and_body_part_affected
      t.string :location_of_incident
      t.string :on_employer_premises
      t.string :department_where_event_occurred
      t.text :activity_at_time_of_incident
      t.text :how_the_injury_occurred
      t.string :physician_name
      t.string :physician_address
      t.string :physician_phone
      t.string :hospital_name
      t.string :hospital_address
      t.string :hospital_phone
      t.string :hospitalized_overnight
      t.string :investigator_name
      t.string :investigator_title
      t.string :investigator_phone
      t.text :nature_of_incident
      t.text :cause_of_incident
      t.text :root_cause
      t.text :assessment_of_future_severity_potential
      t.text :assessment_of_probability_of_recurrence
      t.string :unsafe_condition_corrected_immediately
      t.string :checklistprocedurestraining_modified
      t.string :person_responsible_for_corrective_action
      t.string :title
      t.string :corrective_department
      t.string :corrective_phone
      t.datetime :targeted_completion_date
      t.datetime :actual_completion_date
      t.string :osha_recordable
      t.string :osha_reportable
      t.string :reportable_injury_codes
      t.timestamps
    end
    add_index :rm75_forms, :employee_id
    add_index :rm75_forms, :approver_id

    # Testyyy Forms (dynamic form builder test)
    create_table :testyyy_forms do |t|
      t.string :employee_id
      t.string :name
      t.string :phone
      t.string :email
      t.string :agency
      t.string :division
      t.string :department
      t.string :unit
      t.timestamps
    end

    # Authorization FOs
    create_table :authorization_fos do |t|
      t.string :employee_id
      t.string :name
      t.string :phone
      t.string :email
      t.string :agency
      t.string :division
      t.string :department
      t.string :unit
      t.timestamps
    end
  end
end
