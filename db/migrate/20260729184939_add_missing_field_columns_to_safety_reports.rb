# frozen_string_literal: true

# The form builder generates views, model and controller for a form's fields
# but does not add columns for scalar fields on an existing table, so these
# thirteen fields rendered against attributes that did not exist — every
# new/edit render of a Safety Report raised NoMethodError.
#
# Types follow FormField#child_column_type, the mapping the builder uses when
# it does write columns (for repeating-section child tables), except for
# medical_record_number_for_the_employee: it is a `number` field, which maps to
# :integer, but it holds an identifier rather than a quantity and sits next to
# two `text` medical number fields, so it is a string like its siblings.
class AddMissingFieldColumnsToSafetyReports < ActiveRecord::Migration[8.0]
  def change
    change_table :safety_reports, bulk: true do |t|
      t.string :medical_record_number_for_the_employee
      t.text   :impacted_employee
      t.string :impacted_employees_email
      t.string :impacted_employees_phone
      t.string :impacted_employees_supervisor
      t.text   :location_description
      t.string :is_the_source_blood_tested
      t.string :is_the_employees_blood_tested
      t.string :source_patient_medical_number
      t.string :employee_medical_number
      t.string :other_hospital
      t.string :other_hospital_address
      t.string :other_hospital_phone
    end
  end
end
