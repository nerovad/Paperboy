# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_04_20_000001) do
  create_table "Employee_Groups", force: :cascade do |t|
    t.integer "EmployeeID", null: false
    t.bigint "GroupID", null: false
    t.datetime "Assigned_At", precision: nil, default: -> { "getdate()" }
    t.integer "Assigned_By"
    t.index ["EmployeeID", "GroupID"], name: "idx_employee_groups_on_employee_group", unique: true
  end

  create_table "Group_Permissions", primary_key: ["GroupID", "Permission_Type", "Permission_Key"], force: :cascade do |t|
    t.integer "GroupID", null: false
    t.string "Permission_Type", limit: 50, null: false
    t.string "Permission_Key", limit: 255, null: false
    t.datetime "Created_At", default: -> { "getdate()" }, null: false
  end

  create_table "Groups", primary_key: "GroupID", id: :integer, force: :cascade do |t|
    t.string "Group_Name", limit: 100, null: false
    t.string "Description", limit: 500
    t.datetime "Created_At", precision: nil, default: -> { "getdate()" }
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
  end

  create_table "authorization_fos", force: :cascade do |t|
    t.string "employee_id"
    t.string "name"
    t.string "phone"
    t.string "email"
    t.string "agency"
    t.string "division"
    t.string "department"
    t.string "unit"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "authorization_managers", force: :cascade do |t|
    t.string "employee_id", null: false
    t.string "department_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "authorized_approvers", force: :cascade do |t|
    t.string "employee_id", null: false
    t.string "department_id", null: false
    t.string "service_type", null: false
    t.string "key_type"
    t.string "span"
    t.text "budget_units"
    t.text "locations"
    t.string "authorized_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "bike_locker_forms", force: :cascade do |t|
    t.string "employee_id"
    t.string "name"
    t.string "phone"
    t.string "email"
    t.string "agency"
    t.string "division"
    t.string "department"
    t.string "unit"
    t.integer "status", default: 0
    t.string "approver_id"
    t.text "deny_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approver_id"], name: "index_bike_locker_forms_on_approver_id"
    t.index ["employee_id"], name: "index_bike_locker_forms_on_employee_id"
  end

  create_table "carpool_forms", force: :cascade do |t|
    t.string "employee_id"
    t.string "name"
    t.string "phone"
    t.string "email"
    t.string "agency"
    t.string "division"
    t.string "department"
    t.string "unit"
    t.integer "status", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "creative_job_requests", force: :cascade do |t|
    t.string "job_id"
    t.string "job_title"
    t.string "job_type"
    t.string "job_agency"
    t.string "job_division"
    t.string "job_department"
    t.string "job_unit"
    t.string "asset_type"
    t.string "employee_name"
    t.string "location"
    t.date "date"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "critical_information_reportings", force: :cascade do |t|
    t.string "employee_id"
    t.string "name"
    t.string "phone"
    t.string "email"
    t.string "agency"
    t.string "division"
    t.string "department"
    t.string "unit"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "incident_type"
    t.text "incident_details"
    t.text "cause"
    t.text "staff_involved"
    t.datetime "impact_started"
    t.string "location"
    t.datetime "actual_completion_date"
    t.string "urgency"
    t.string "impact"
    t.string "impacted_customers"
    t.text "next_steps"
    t.integer "status", default: 0
    t.string "assigned_manager_id"
    t.string "building"
    t.string "other_building"
    t.string "impacted_agency"
    t.string "impacted_employee"
  end

  create_table "form_fields", force: :cascade do |t|
    t.bigint "form_template_id", null: false
    t.string "field_name", null: false
    t.string "field_type", null: false
    t.string "label"
    t.integer "page_number", null: false
    t.integer "position"
    t.text "options"
    t.boolean "required", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "restricted_to_type", default: "none"
    t.integer "restricted_to_employee_id"
    t.integer "restricted_to_group_id"
    t.integer "conditional_field_id"
    t.text "conditional_values"
    t.string "read_only", default: "none"
    t.integer "conditional_answer_field_id"
    t.text "conditional_answer_mappings"
    t.boolean "has_custom_view", default: false, null: false
  end

  create_table "form_template_routing_steps", force: :cascade do |t|
    t.bigint "form_template_id", null: false
    t.integer "step_number", null: false
    t.string "routing_type", null: false
    t.integer "employee_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "form_template_status_id"
    t.string "display_name"
  end

  create_table "form_template_statuses", force: :cascade do |t|
    t.bigint "form_template_id", null: false
    t.string "name", null: false
    t.string "key", null: false
    t.string "category", null: false
    t.integer "position", default: 0
    t.boolean "is_initial", default: false
    t.boolean "is_end", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "auto_generated", default: false
  end

  create_table "form_templates", force: :cascade do |t|
    t.string "name", null: false
    t.string "class_name", null: false
    t.integer "page_count", default: 2, null: false
    t.text "page_headers"
    t.integer "created_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "submission_type", default: "database"
    t.string "approval_routing_to"
    t.integer "approval_employee_id"
    t.string "powerbi_workspace_id"
    t.string "powerbi_report_id"
    t.boolean "has_dashboard", default: false
    t.text "inbox_buttons"
    t.string "status_transition_mode", default: "automatic"
    t.text "tags"
    t.string "visibility", default: "restricted", null: false
  end

  create_table "gym_locker_forms", force: :cascade do |t|
    t.string "employee_id"
    t.string "name"
    t.string "phone"
    t.string "email"
    t.string "agency"
    t.string "division"
    t.string "department"
    t.string "unit"
    t.integer "status", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "help_tickets", force: :cascade do |t|
    t.string "subject", null: false
    t.text "description", null: false
    t.string "employee_id", null: false
    t.string "employee_name"
    t.string "employee_email"
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "leave_of_absence_forms", force: :cascade do |t|
    t.string "employee_id"
    t.string "name"
    t.string "phone"
    t.string "email"
    t.string "agency"
    t.string "division"
    t.string "department"
    t.string "unit"
    t.integer "status", default: 0
    t.string "approver_id"
    t.text "deny_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "notice_of_change_forms", force: :cascade do |t|
    t.string "employee_id"
    t.string "name"
    t.string "phone"
    t.string "email"
    t.string "agency"
    t.string "division"
    t.string "department"
    t.string "unit"
    t.integer "status", default: 0
    t.string "approver_id"
    t.text "deny_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "org_permissions", force: :cascade do |t|
    t.string "agency_id"
    t.string "division_id"
    t.string "department_id"
    t.string "unit_id"
    t.string "permission_type", null: false
    t.string "permission_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "osha_reports", force: :cascade do |t|
    t.string "employee_id"
    t.string "name"
    t.string "phone"
    t.string "email"
    t.string "agency"
    t.string "division"
    t.string "department"
    t.string "unit"
    t.integer "status", default: 0
    t.string "approver_id"
    t.text "deny_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "safety_report_id"
    t.string "street"
    t.string "city"
    t.string "state"
    t.string "zip"
    t.datetime "date_of_birth"
    t.datetime "date_hired"
    t.string "sex"
    t.string "name_of_physician_or_other_health_care_professional"
    t.string "was_treatment_given_away_from_the_worksite"
    t.string "facility_name"
    t.string "facility_street_address"
    t.string "facility_city"
    t.string "facility_state"
    t.string "facility_zip"
    t.string "was_the_employee_treated_in_an_emergency_room"
    t.string "was_the_employee_hospitalized_overnight_as_an_inpatient"
    t.string "case_number_from_the_log"
    t.datetime "date_of_injury_or_illness"
    t.datetime "time_employee_began_work"
    t.datetime "time_of_event"
    t.text "what_happened_tell_us_how_the_injury_occurred"
    t.text "what_was_the_injury_or_illness"
    t.text "what_was_the_employee_doing_just_before_the_incident_occurred"
    t.text "what_object_or_substance_directly_harmed_the_employee"
    t.string "did_employee_die"
    t.datetime "date_of_death"
  end

  create_table "parking_lot_submissions", force: :cascade do |t|
    t.string "name", limit: 200
    t.string "phone", limit: 25
    t.string "employee_id", limit: 20
    t.string "email", limit: 200
    t.string "agency", limit: 100
    t.string "division", limit: 100
    t.string "department", limit: 100
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "unit", limit: 100
    t.integer "status"
    t.string "supervisor_id", limit: 20
    t.string "approved_by", limit: 20
    t.datetime "approved_at"
    t.string "denied_by", limit: 20
    t.datetime "denied_at"
    t.text "denial_reason"
    t.string "supervisor_email", limit: 200
    t.string "delegated_approver_id"
    t.string "delegated_approver_email"
    t.string "delegated_approved_by"
    t.datetime "delegated_approved_at"
    t.text "carpool_participants"
    t.string "other_permit_type", limit: 200
  end

  create_table "parking_lot_vehicles", force: :cascade do |t|
    t.bigint "parking_lot_submission_id", null: false
    t.string "make", limit: 50
    t.string "model", limit: 50
    t.string "color", limit: 20
    t.integer "year"
    t.string "license_plate", limit: 15
    t.string "parking_lot", limit: 100
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "other_parking_lot", limit: 100
    t.text "permit_type"
  end

  create_table "pcard_inventories", force: :cascade do |t|
    t.string "last_name"
    t.string "first_name"
    t.string "agency"
    t.string "division"
    t.string "mail_stop"
    t.string "address"
    t.string "city"
    t.string "state"
    t.string "zip"
    t.string "phone"
    t.decimal "single_purchase_limit", precision: 10, scale: 2
    t.decimal "monthly_limit", precision: 10, scale: 2
    t.string "card_number"
    t.date "issued_date"
    t.date "expiration_date"
    t.date "canceled_date"
    t.string "agent"
    t.string "company"
    t.string "division_number"
    t.string "approver_name"
    t.string "org_number"
    t.string "dept_head_agency"
    t.string "billing_contact"
    t.bigint "pcard_request_form_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "card_last_four", limit: 4
  end

  create_table "pcard_request_forms", force: :cascade do |t|
    t.string "employee_id"
    t.string "name"
    t.string "phone"
    t.string "email"
    t.string "agency"
    t.string "division"
    t.string "department"
    t.string "unit"
    t.integer "status", default: 0
    t.string "approver_id"
    t.text "deny_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "probation_transfer_requests", force: :cascade do |t|
    t.string "employee_id", limit: 20
    t.string "name", limit: 200
    t.string "email", limit: 200
    t.string "phone", limit: 25
    t.string "agency", limit: 100
    t.string "division", limit: 100
    t.string "department", limit: 100
    t.string "unit", limit: 100
    t.string "work_location", limit: 100
    t.date "current_assignment_date"
    t.text "desired_transfer_destination"
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "other_transfer_destination", limit: 200
    t.string "approved_by", limit: 20
    t.datetime "approved_at"
    t.string "denied_by", limit: 20
    t.datetime "denied_at"
    t.text "denial_reason"
    t.string "supervisor_email", limit: 200
    t.string "supervisor_id", limit: 20
    t.datetime "expires_at"
    t.datetime "canceled_at"
    t.string "canceled_reason", limit: 100
    t.bigint "superseded_by_id"
    t.string "approved_destination"
  end

  create_table "safety_reports", force: :cascade do |t|
    t.string "employee_id"
    t.string "name"
    t.string "phone"
    t.string "email"
    t.string "agency"
    t.string "division"
    t.string "department"
    t.string "unit"
    t.integer "status", default: 0
    t.string "approver_id"
    t.text "deny_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "report_type"
    t.string "bloodborne_pathogen_exposure"
    t.string "supervisor_name"
    t.string "witness_name"
    t.string "witness_phone"
    t.datetime "date_of_injury_or_illness"
    t.datetime "date_employer_notified"
    t.datetime "date_dwc1_given"
    t.string "who_gave_the_dwc1"
    t.datetime "date_last_worked"
    t.datetime "date_returned_to_work"
    t.string "missed_full_work_day_"
    t.string "still_off_work"
    t.text "specific_injury_and_body_part_affected"
    t.string "location_of_incident"
    t.string "on_employer_premises"
    t.string "department_where_event_occurred"
    t.text "activity_at_time_of_incident"
    t.text "how_the_injury_occurred"
    t.string "physician_name"
    t.string "physician_address"
    t.string "physician_phone"
    t.string "hospital_name"
    t.string "hospital_address"
    t.string "hospital_phone"
    t.string "hospitalized_overnight"
    t.string "investigator_name"
    t.string "investigator_title"
    t.string "investigator_phone"
    t.text "nature_of_incident"
    t.text "cause_of_incident"
    t.text "root_cause"
    t.text "assessment_of_future_severity_potential"
    t.text "assessment_of_probability_of_recurrence"
    t.string "unsafe_condition_corrected_immediately"
    t.string "checklistprocedurestraining_modified"
    t.string "person_responsible_for_corrective_action"
    t.string "title"
    t.string "corrective_department"
    t.string "corrective_phone"
    t.datetime "targeted_completion_date"
    t.datetime "actual_completion_date"
    t.string "osha_recordable"
    t.string "osha_reportable"
    t.string "reportable_injury_codes"
  end

  create_table "saved_searches", force: :cascade do |t|
    t.string "employee_id", null: false
    t.string "name", null: false
    t.text "filters", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "scheduled_reports", force: :cascade do |t|
    t.string "employee_id", null: false
    t.string "form_type", null: false
    t.string "format", default: "csv", null: false
    t.string "status_filter"
    t.string "frequency", null: false
    t.string "time_of_day", null: false
    t.integer "day_of_week"
    t.integer "day_of_month"
    t.string "date_range_type", null: false
    t.boolean "enabled", default: true, null: false
    t.datetime "last_run_at"
    t.datetime "next_run_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "social_media_forms", force: :cascade do |t|
    t.string "employee_id"
    t.string "name"
    t.string "phone"
    t.string "email"
    t.string "agency"
    t.string "division"
    t.string "department"
    t.string "unit"
    t.integer "status", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "status_changes", force: :cascade do |t|
    t.string "trackable_type", null: false
    t.bigint "trackable_id", null: false
    t.string "from_status"
    t.string "to_status", null: false
    t.string "changed_by_id"
    t.string "changed_by_name"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "task_reassignments", force: :cascade do |t|
    t.string "task_type", null: false
    t.bigint "task_id", null: false
    t.string "from_employee_id", null: false
    t.string "to_employee_id", null: false
    t.string "reassigned_by_id", null: false
    t.text "reason"
    t.string "assignment_field"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tasks", primary_key: ["agency_id", "task_id"], force: :cascade do |t|
    t.string "agency_id", limit: 3, null: false
    t.string "task_id", limit: 4, null: false
    t.string "long_name", limit: 100, null: false
    t.string "short_name", limit: 50, null: false
  end

  create_table "testyyy_forms", force: :cascade do |t|
    t.string "employee_id"
    t.string "name"
    t.string "phone"
    t.string "email"
    t.string "agency"
    t.string "division"
    t.string "department"
    t.string "unit"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "user_settings", force: :cascade do |t|
    t.string "employee_id", null: false
    t.boolean "inbox_email_notifications", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_user_settings_on_employee_id", unique: true
  end

  create_table "work_schedule_or_location_update_forms", force: :cascade do |t|
    t.string "employee_id"
    t.string "name"
    t.string "phone"
    t.string "email"
    t.string "agency"
    t.string "division"
    t.string "department"
    t.string "unit"
    t.integer "status", default: 0
    t.string "approver_id"
    t.text "deny_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "workplace_violence_forms", force: :cascade do |t|
    t.string "employee_id"
    t.string "name"
    t.string "phone"
    t.string "email"
    t.string "agency"
    t.string "division"
    t.string "department"
    t.string "unit"
    t.integer "status", default: 0
    t.string "approver_id"
    t.text "deny_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "form_fields", "form_templates"
  add_foreign_key "form_template_routing_steps", "form_template_statuses"
  add_foreign_key "form_template_routing_steps", "form_templates"
  add_foreign_key "form_template_statuses", "form_templates"
  add_foreign_key "parking_lot_vehicles", "parking_lot_submissions"
  add_foreign_key "pcard_inventories", "pcard_request_forms"
end
