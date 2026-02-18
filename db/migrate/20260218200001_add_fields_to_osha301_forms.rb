class AddFieldsToOsha301Forms < ActiveRecord::Migration[7.1]
  def change
    change_table :osha301_forms, bulk: true do |t|
      # FK back to source RM75
      t.bigint :rm75_form_id

      # Page 3: Employee demographics
      t.string :street
      t.string :city
      t.string :state
      t.string :zip
      t.datetime :date_of_birth
      t.datetime :date_hired
      t.string :sex
      t.string :name_of_physician_or_other_health_care_professional

      # Page 4: Treatment info
      t.string :was_treatment_given_away_from_the_worksite
      t.string :facility_name
      t.string :facility_street_address
      t.string :facility_city
      t.string :facility_state
      t.string :facility_zip
      t.string :was_the_employee_treated_in_an_emergency_room
      t.string :was_the_employee_hospitalized_overnight_as_an_inpatient

      # Page 5: Case details
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
    end

    add_index :osha301_forms, :rm75_form_id
  end
end
