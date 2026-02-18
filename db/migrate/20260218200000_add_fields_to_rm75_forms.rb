class AddFieldsToRm75Forms < ActiveRecord::Migration[7.1]
  def change
    change_table :rm75_forms, bulk: true do |t|
      # Page 3: Report
      t.string :report_type
      t.string :bloodborne_pathogen_exposure

      # Page 4: Supervisor and Witness Info
      t.string :supervisor_name
      t.string :witness_name
      t.string :witness_phone

      # Page 5: Incident Dates and Status
      t.datetime :date_of_injury_or_illness
      t.datetime :date_employer_notified
      t.datetime :date_dwc1_given
      t.string :who_gave_the_dwc1
      t.datetime :date_last_worked
      t.datetime :date_returned_to_work
      t.string :missed_full_work_day_
      t.string :still_off_work

      # Page 6: Incident Description
      t.text :specific_injury_and_body_part_affected
      t.string :location_of_incident
      t.string :on_employer_premises
      t.string :department_where_event_occurred
      t.text :activity_at_time_of_incident
      t.text :how_the_injury_occurred

      # Page 7: Medical Info
      t.string :physician_name
      t.string :physician_address
      t.string :physician_phone
      t.string :hospital_name
      t.string :hospital_address
      t.string :hospital_phone
      t.string :hospitalized_overnight

      # Page 8: Investigation Details
      t.string :investigator_name
      t.string :investigator_title
      t.string :investigator_phone
      t.text :nature_of_incident
      t.text :cause_of_incident

      # Page 9: Severity & Root Cause
      t.text :root_cause
      t.text :assessment_of_future_severity_potential
      t.text :assessment_of_probability_of_recurrence

      # Page 10: Corrective Actions
      t.string :unsafe_condition_corrected_immediately
      t.string :checklistprocedurestraining_modified
      t.string :person_responsible_for_corrective_action
      t.string :title
      t.string :corrective_department
      t.string :corrective_phone
      t.datetime :targeted_completion_date
      t.datetime :actual_completion_date

      # Page 11: OSHA Info
      t.string :osha_recordable
      t.string :osha_reportable
      t.string :reportable_injury_codes
    end
  end
end
