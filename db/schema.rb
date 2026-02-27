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

ActiveRecord::Schema[8.0].define(version: 2026_02_27_000010) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
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
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
    t.index ["blob_id"], name: "index_active_storage_variant_records_on_blob_id"
  end

  create_table "activities", primary_key: ["agency_id", "activity_id"], force: :cascade do |t|
    t.string "agency_id", limit: 3, null: false
    t.string "activity_id", limit: 4, null: false
    t.string "long_name", limit: 100, null: false
    t.string "short_name", limit: 50, null: false
  end

  create_table "agencies", primary_key: "agency_id", id: { type: :string, limit: 3 }, force: :cascade do |t|
    t.string "name", limit: 100, null: false
    t.string "long_name", limit: 100, null: false
    t.string "short_name", limit: 50, null: false
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
    t.index ["employee_id", "department_id"], name: "index_authorization_managers_on_employee_id_and_department_id", unique: true
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
    t.index ["department_id", "service_type"], name: "index_authorized_approvers_on_department_id_and_service_type"
    t.index ["employee_id"], name: "index_authorized_approvers_on_employee_id"
  end

  create_table "brown_mail_forms", force: :cascade do |t|
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "department_funds", primary_key: ["agency_id", "fund_id"], force: :cascade do |t|
    t.string "agency_id", limit: 3, null: false
    t.string "fund_id", limit: 4, null: false
  end

  create_table "departments", primary_key: ["agency_id", "division_id", "department_id"], force: :cascade do |t|
    t.string "agency_id", limit: 3, null: false
    t.string "division_id", limit: 4, null: false
    t.string "department_id", limit: 4, null: false
    t.string "long_name", limit: 100, null: false
    t.string "short_name", limit: 50, null: false
  end

  create_table "divisions", primary_key: ["agency_id", "division_id"], force: :cascade do |t|
    t.string "agency_id", limit: 3, null: false
    t.string "division_id", limit: 4, null: false
    t.string "long_name", limit: 100, null: false
    t.string "short_name", limit: 50, null: false
  end

  create_table "employee_groups", force: :cascade do |t|
    t.integer "employee_id", null: false
    t.bigint "group_id", null: false
    t.datetime "assigned_at", default: -> { "CURRENT_TIMESTAMP" }
    t.integer "assigned_by"
    t.index ["employee_id", "group_id"], name: "index_employee_groups_on_employee_id_and_group_id", unique: true
  end

  create_table "employees", primary_key: "employee_id", id: :integer, default: nil, force: :cascade do |t|
    t.string "first_name", limit: 50
    t.string "last_name", limit: 50
    t.string "email", limit: 50
    t.string "work_phone", limit: 50
    t.integer "supervisor_id"
    t.string "supervisor_first_name", limit: 50
    t.string "supervisor_last_name", limit: 50
    t.string "job_title", limit: 50
    t.string "job_code", limit: 50
    t.integer "job_class"
    t.string "pay_status", limit: 50
    t.string "union_code", limit: 50
    t.string "employee_type", limit: 50
    t.string "agency", limit: 50
    t.string "department", limit: 50
    t.string "unit", limit: 50
    t.string "position", limit: 50
    t.index ["employee_id"], name: "index_employees_on_employee_id", unique: true
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
    t.string "restricted_to_type", default: "none"
    t.integer "restricted_to_employee_id"
    t.integer "restricted_to_group_id"
    t.integer "conditional_field_id"
    t.text "conditional_values"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conditional_field_id"], name: "index_form_fields_on_conditional_field_id"
    t.index ["form_template_id", "page_number"], name: "index_form_fields_on_form_template_id_and_page_number"
    t.index ["form_template_id", "position"], name: "index_form_fields_on_form_template_id_and_position"
    t.index ["form_template_id"], name: "index_form_fields_on_form_template_id"
    t.index ["restricted_to_type"], name: "index_form_fields_on_restricted_to_type"
  end

  create_table "form_template_routing_steps", force: :cascade do |t|
    t.bigint "form_template_id", null: false
    t.integer "step_number", null: false
    t.string "routing_type", null: false
    t.integer "employee_id"
    t.bigint "form_template_status_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["form_template_id", "step_number"], name: "idx_routing_steps_template_step", unique: true
    t.index ["form_template_id"], name: "index_form_template_routing_steps_on_form_template_id"
    t.index ["form_template_status_id"], name: "index_form_template_routing_steps_on_form_template_status_id"
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
    t.index ["form_template_id", "key"], name: "index_form_template_statuses_on_form_template_id_and_key", unique: true
    t.index ["form_template_id", "position"], name: "index_form_template_statuses_on_form_template_id_and_position"
    t.index ["form_template_id"], name: "index_form_template_statuses_on_form_template_id"
  end

  create_table "form_templates", force: :cascade do |t|
    t.string "name", null: false
    t.string "class_name", null: false
    t.string "access_level", default: "public", null: false
    t.integer "acl_group_id"
    t.integer "page_count", default: 2, null: false
    t.text "page_headers"
    t.integer "created_by"
    t.string "submission_type", default: "database"
    t.string "approval_routing_to"
    t.integer "approval_employee_id"
    t.string "powerbi_workspace_id"
    t.string "powerbi_report_id"
    t.boolean "has_dashboard", default: false
    t.text "inbox_buttons"
    t.string "status_transition_mode", default: "automatic"
    t.text "tags"
    t.string "org_scope_type"
    t.string "org_scope_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["class_name"], name: "index_form_templates_on_class_name", unique: true
  end

  create_table "functions", primary_key: ["agency_id", "function_id"], force: :cascade do |t|
    t.string "agency_id", limit: 3, null: false
    t.string "function_id", limit: 4, null: false
    t.string "long_name", limit: 100, null: false
    t.string "short_name", limit: 50, null: false
  end

  create_table "funds", primary_key: "fund_id", id: { type: :string, limit: 4 }, force: :cascade do |t|
    t.string "long_name", limit: 100, null: false
    t.string "short_name", limit: 50, null: false
    t.string "fund_class", limit: 50, null: false
    t.string "fund_category", limit: 50, null: false
    t.string "fund_type", limit: 50, null: false
    t.string "fund_group", limit: 50, null: false
    t.string "cafr_type", limit: 50, null: false
  end

  create_table "group_permissions", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.string "permission_type", limit: 50, null: false
    t.string "permission_key", limit: 255, null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["group_id", "permission_type", "permission_key"], name: "idx_group_permissions_unique", unique: true
  end

  create_table "groups", force: :cascade do |t|
    t.string "group_name", limit: 100, null: false
    t.string "description", limit: 500
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }
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
    t.index ["employee_id"], name: "index_help_tickets_on_employee_id"
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
    t.index ["approver_id"], name: "index_leave_of_absence_forms_on_approver_id"
    t.index ["employee_id"], name: "index_leave_of_absence_forms_on_employee_id"
  end

  create_table "major_programs", primary_key: ["agency_id", "major_program_id"], force: :cascade do |t|
    t.string "agency_id", limit: 3, null: false
    t.string "major_program_id", limit: 10, null: false
    t.string "long_name", limit: 100, null: false
    t.string "short_name", limit: 50, null: false
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
    t.index ["approver_id"], name: "index_notice_of_change_forms_on_approver_id"
    t.index ["employee_id"], name: "index_notice_of_change_forms_on_employee_id"
  end

  create_table "objects", primary_key: "object_id", id: { type: :integer, limit: 2, default: nil }, force: :cascade do |t|
    t.string "long_name", limit: 100, null: false
    t.string "short_name", limit: 50, null: false
  end

  create_table "osha301_forms", force: :cascade do |t|
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
    t.bigint "rm75_form_id"
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approver_id"], name: "index_osha301_forms_on_approver_id"
    t.index ["employee_id"], name: "index_osha301_forms_on_employee_id"
    t.index ["rm75_form_id"], name: "index_osha301_forms_on_rm75_form_id"
  end

  create_table "parking_lot_submissions", force: :cascade do |t|
    t.string "name", limit: 200
    t.string "phone", limit: 25
    t.string "employee_id", limit: 20
    t.string "email", limit: 200
    t.string "agency", limit: 100
    t.string "division", limit: 100
    t.string "department", limit: 100
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "parking_lot_vehicles", force: :cascade do |t|
    t.bigint "parking_lot_submission_id", null: false
    t.string "make", limit: 50
    t.string "model", limit: 50
    t.string "color", limit: 20
    t.integer "year"
    t.string "license_plate", limit: 15
    t.string "parking_lot", limit: 100
    t.string "other_parking_lot", limit: 100
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parking_lot_submission_id"], name: "index_parking_lot_vehicles_on_parking_lot_submission_id"
  end

  create_table "phases", primary_key: ["agency_id", "phase_id"], force: :cascade do |t|
    t.string "agency_id", limit: 3, null: false
    t.string "phase_id", limit: 6, null: false
    t.string "long_name", limit: 100, null: false
    t.string "short_name", limit: 50, null: false
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_destination"], name: "index_probation_transfer_requests_on_approved_destination"
    t.index ["canceled_at"], name: "index_probation_transfer_requests_on_canceled_at"
    t.index ["expires_at"], name: "index_probation_transfer_requests_on_expires_at"
    t.index ["status"], name: "index_probation_transfer_requests_on_status"
    t.index ["superseded_by_id"], name: "index_probation_transfer_requests_on_superseded_by_id"
  end

  create_table "programs", primary_key: ["agency_id", "program_id", "major_program_id"], force: :cascade do |t|
    t.string "agency_id", limit: 3, null: false
    t.string "program_id", limit: 10, null: false
    t.string "major_program_id", limit: 10, null: false
    t.string "long_name", limit: 100, null: false
    t.string "short_name", limit: 50, null: false
  end

  create_table "revenue_sources", primary_key: "revenue_id", id: { type: :integer, limit: 2, default: nil }, force: :cascade do |t|
    t.string "long_name", limit: 100, null: false
    t.string "short_name", limit: 50, null: false
  end

  create_table "rm75_forms", force: :cascade do |t|
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approver_id"], name: "index_rm75_forms_on_approver_id"
    t.index ["employee_id"], name: "index_rm75_forms_on_employee_id"
  end

  create_table "saved_searches", force: :cascade do |t|
    t.string "employee_id", null: false
    t.string "name", null: false
    t.text "filters", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id", "name"], name: "index_saved_searches_on_employee_id_and_name", unique: true
    t.index ["employee_id"], name: "index_saved_searches_on_employee_id"
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
    t.index ["employee_id"], name: "index_scheduled_reports_on_employee_id"
    t.index ["enabled"], name: "index_scheduled_reports_on_enabled"
    t.index ["next_run_at"], name: "index_scheduled_reports_on_next_run_at"
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
    t.index ["changed_by_id"], name: "index_status_changes_on_changed_by_id"
    t.index ["trackable_type", "trackable_id"], name: "index_status_changes_on_trackable_type_and_trackable_id"
  end

  create_table "sub_objects", primary_key: ["agency_id", "object_id", "sub_object_id"], force: :cascade do |t|
    t.string "agency_id", limit: 3, null: false
    t.integer "object_id", limit: 2, null: false
    t.string "sub_object_id", limit: 4, null: false
  end

  create_table "sub_units", primary_key: ["agency_id", "unit_id", "subunit_id"], force: :cascade do |t|
    t.string "agency_id", limit: 3, null: false
    t.string "unit_id", limit: 4, null: false
    t.string "subunit_id", limit: 4, null: false
    t.string "short_name", limit: 50, null: false
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
    t.index ["from_employee_id"], name: "index_task_reassignments_on_from_employee_id"
    t.index ["task_type", "task_id"], name: "index_task_reassignments_on_task_type_and_task_id"
    t.index ["to_employee_id"], name: "index_task_reassignments_on_to_employee_id"
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

  create_table "units", primary_key: ["agency_id", "division_id", "department_id", "unit_id"], force: :cascade do |t|
    t.string "agency_id", limit: 3, null: false
    t.string "division_id", limit: 4, null: false
    t.string "department_id", limit: 4, null: false
    t.string "unit_id", limit: 4, null: false
    t.string "long_name", limit: 100, null: false
    t.string "short_name", limit: 50, null: false
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
    t.index ["approver_id"], name: "index_work_schedule_or_location_update_forms_on_approver_id"
    t.index ["employee_id"], name: "index_work_schedule_or_location_update_forms_on_employee_id"
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
    t.index ["approver_id"], name: "index_workplace_violence_forms_on_approver_id"
    t.index ["employee_id"], name: "index_workplace_violence_forms_on_employee_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "employee_groups", "employees", primary_key: "employee_id"
  add_foreign_key "employee_groups", "groups"
  add_foreign_key "form_fields", "form_templates"
  add_foreign_key "form_template_routing_steps", "form_template_statuses"
  add_foreign_key "form_template_routing_steps", "form_templates"
  add_foreign_key "form_template_statuses", "form_templates"
  add_foreign_key "group_permissions", "groups"
  add_foreign_key "parking_lot_vehicles", "parking_lot_submissions"
end
