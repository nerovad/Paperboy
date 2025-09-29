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

ActiveRecord::Schema[8.0].define(version: 2025_09_29_185620) do
  create_table "BdmRateTypes", primary_key: "RateID", id: { type: :integer, limit: 2 }, force: :cascade do |t|
    t.string "Description", limit: 150, null: false
    t.string "UOM", limit: 15, null: false
  end

  create_table "BdmRates", primary_key: ["FYEAR", "RateID"], force: :cascade do |t|
    t.string "FYEAR", limit: 4, null: false
    t.integer "RateID", limit: 2, null: false
    t.integer "ObjectID", limit: 2, null: false
    t.float "Rate", null: false
    t.integer "UnitID", limit: 2, null: false
  end

  create_table "BusinessUnit", id: :integer, default: 4641, force: :cascade do |t|
    t.varchar "name", limit: 50, null: false
  end

  create_table "CustomerAccount", primary_key: "CustomerAccountID", id: :integer, force: :cascade do |t|
    t.string "FYEAR", limit: 4, null: false
    t.string "CUNIT", limit: 4, null: false
    t.string "CACTIVITY", limit: 4, null: false
    t.string "CFUNCTION", limit: 4, null: false
    t.string "CPROGRAM", limit: 10
    t.string "CPHASE", limit: 6
    t.string "CTASK", limit: 4
  end

  create_table "CustomerAccountWithType", primary_key: "CustomerAccountID", id: :integer, force: :cascade do |t|
    t.string "FYEAR", limit: 4, null: false
    t.string "CUNIT", limit: 4, null: false
    t.string "CACTIVITY", limit: 4, null: false
    t.string "CFUNCTION", limit: 4, null: false
    t.string "CPROGRAM", limit: 10
    t.string "CPHASE", limit: 6
    t.string "CTASK", limit: 4
    t.string "TYPE", limit: 3, null: false
  end

  create_table "Employees", primary_key: "EmployeeID", id: :integer, default: nil, force: :cascade do |t|
    t.string "Last_Name", limit: 50
    t.string "First_Name", limit: 50
    t.string "Job_Title", limit: 50
    t.string "Work_Phone", limit: 50
    t.string "Agency", limit: 50
    t.string "Unit", limit: 50
    t.integer "Job_Code", limit: 2
    t.string "Position", limit: 50
    t.string "Pay_Status", limit: 50
    t.integer "Job_Class", limit: 1
    t.string "Department", limit: 50
    t.string "Type", limit: 50
    t.integer "Supervisor_ID"
    t.string "Supervisor_Last_Name", limit: 50
    t.string "Supervisor_First_Name", limit: 50
    t.string "EE_Email", limit: 50
    t.string "Union_Code", limit: 50
  end

  create_table "FiscalMonths", id: false, force: :cascade do |t|
    t.varchar "ApMon", limit: 4, null: false
    t.integer "MonNbr", null: false
  end

  create_table "FiscalYears", id: false, force: :cascade do |t|
    t.varchar "Year", limit: 4, null: false
    t.date "sDate", null: false
    t.date "eDate", null: false
  end

  create_table "PlanVsActual", id: false, force: :cascade do |t|
    t.varchar "YEAR", limit: 4, null: false
    t.varchar "PLAN", limit: 1, null: false
    t.varchar "TYPE", limit: 3, null: false
    t.varchar "SERVICE", limit: 15, null: false
    t.varchar "SERVICETYPE", limit: 15, null: false
    t.float "Jul", null: false
    t.float "Aug", null: false
    t.float "Sep", null: false
    t.float "Oct", null: false
    t.float "Nov", null: false
    t.float "Dec", null: false
    t.float "Jan", null: false
    t.float "Feb", null: false
    t.float "Mar", null: false
    t.float "Apr", null: false
    t.float "May", null: false
    t.float "Jun", null: false
  end

  create_table "TC60", id: false, force: :cascade do |t|
    t.varchar "TYPE", limit: 3, null: false
    t.varchar "CUNIT", limit: 4, null: false
    t.integer "COBJECT", null: false
    t.varchar "CACTIVITY", limit: 4
    t.varchar "CFUNCTION", limit: 4
    t.varchar "CPROGRAM", limit: 10
    t.varchar "CPHASE", limit: 6
    t.varchar "CTASK", limit: 4
    t.float "AMOUNT", default: 0.0
    t.varchar "SUNIT", limit: 4, null: false
    t.integer "SOBJECT", null: false
    t.varchar "SACTIVITY", limit: 4
    t.varchar "SFUNCTION", limit: 4
    t.varchar "SPROGRAM", limit: 10
    t.varchar "SPHASE", limit: 6
    t.varchar "STASK", limit: 4
    t.varchar "POSTING_REF", limit: 20, null: false
    t.varchar "SERVICE", limit: 15, null: false
    t.date "DATE", null: false
    t.varchar "DOC_NMBR", limit: 50
    t.varchar "DESCRIPTION", limit: 50
    t.varchar "OTHER1", limit: 50
    t.varchar "OTHER2", limit: 50
    t.varchar "OTHER3", limit: 50
    t.float "QUANTITY", default: 0.0
    t.float "RATE", default: 0.0
    t.float "COST"
  end

  create_table "TC60_Services", id: false, force: :cascade do |t|
    t.varchar "YEAR", limit: 4, null: false
    t.varchar "TYPE", limit: 3, null: false
    t.varchar "SERVICE", limit: 15, null: false
    t.varchar "SUNIT", limit: 4, null: false
    t.integer "SOBJECT", null: false
    t.varchar "SACTIVITY", limit: 4, null: false
    t.varchar "SFUNCTION", limit: 4, null: false
    t.varchar "SPROGRAM", limit: 10, null: false
    t.varchar "SPHASE", limit: 6, null: false
    t.varchar "STASK", limit: 4, null: false
  end

  create_table "TC60_Types", primary_key: "TYPE", id: { type: :varchar, limit: 3 }, force: :cascade do |t|
    t.boolean "ACTIVE", null: false
    t.varchar "NAME", limit: 30
    t.varchar "funding_type", limit: 10, default: "monthly", null: false
    t.check_constraint "[funding_type]='both' OR [funding_type]='encumbered' OR [funding_type]='monthly'", name: "CK_TC60_Types_funding_type"
  end

  create_table "_stgBdmRateTypes", id: false, force: :cascade do |t|
    t.integer "RateID", limit: 2, null: false
    t.string "Description", limit: 150, null: false
    t.string "UOM", limit: 15, null: false
  end

  create_table "_stgFiscalCursor", id: false, force: :cascade do |t|
    t.varchar "Year", limit: 4, null: false
    t.varchar "ApMon", limit: 4, null: false
    t.integer "MonNbr", null: false
    t.date "sDate", null: false
    t.date "eDate", null: false
    t.boolean "processed", default: false, null: false
  end

  create_table "_stgTC60", id: false, force: :cascade do |t|
    t.varchar "TYPE", limit: 3, null: false
    t.varchar "CUNIT", limit: 4, null: false
    t.integer "COBJECT", null: false
    t.varchar "CACTIVITY", limit: 4
    t.varchar "CFUNCTION", limit: 4
    t.varchar "CPROGRAM", limit: 10
    t.varchar "CPHASE", limit: 6
    t.varchar "CTASK", limit: 4
    t.float "AMOUNT", default: 0.0
    t.varchar "SUNIT", limit: 4, null: false
    t.integer "SOBJECT", null: false
    t.varchar "SACTIVITY", limit: 4
    t.varchar "SFUNCTION", limit: 4
    t.varchar "SPROGRAM", limit: 10
    t.varchar "SPHASE", limit: 6
    t.varchar "STASK", limit: 4
    t.varchar "POSTING_REF", limit: 20, null: false
    t.varchar "SERVICE", limit: 15, null: false
    t.date "DATE", null: false
    t.varchar "DOC_NMBR", limit: 50
    t.varchar "DESCRIPTION", limit: 50
    t.varchar "OTHER1", limit: 50
    t.varchar "OTHER2", limit: 50
    t.varchar "OTHER3", limit: 50
    t.float "QUANTITY", default: 0.0
    t.float "RATE", default: 0.0
    t.float "COST"
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

  create_table "authorization_forms", force: :cascade do |t|
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

  create_table "events", force: :cascade do |t|
    t.string "event_type", null: false
    t.string "subtype"
    t.integer "employee_id", null: false
    t.integer "reported_by_id"
    t.datetime "event_date", null: false
    t.string "location"
    t.boolean "on_premises"
    t.text "initial_summary"
    t.date "date_reported"
    t.date "date_resolved"
    t.string "status", default: "open"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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

  create_table "loa_forms", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.date "last_date_worked"
    t.date "leave_start_date"
    t.date "leave_end_date"
    t.boolean "extension_requested"
    t.text "requested_during_leave"
    t.boolean "applying_for_disability"
    t.string "leave_type"
    t.text "leave_reason"
    t.string "emp_initials_1"
    t.date "initial_date_1"
    t.string "biweekly_hours"
    t.string "pay_status_during_leave"
    t.text "estimated_leave_balances"
    t.text "expected_disability_benefits"
    t.text "notes_1"
    t.boolean "agreed_to_terms"
    t.string "emp_initials_2"
    t.date "initial_date_2"
    t.date "waive_benefits_start_date"
    t.date "waive_benefits_end_date"
    t.text "waived_sources"
    t.string "emp_initials_3"
    t.date "initial_date_3"
    t.boolean "employee_verified_info"
    t.text "notes_2"
    t.string "request_status"
    t.string "team_signature"
    t.string "sig_employee_id"
    t.date "sig_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "employee_id"
    t.string "employee_name"
    t.string "work_email"
    t.index ["employee_id"], name: "index_loa_forms_on_employee_id"
    t.index ["event_id"], name: "index_loa_forms_on_event_id"
  end

  create_table "major_programs", primary_key: ["agency_id", "major_program_id"], force: :cascade do |t|
    t.string "agency_id", limit: 3, null: false
    t.string "major_program_id", limit: 10, null: false
    t.string "long_name", limit: 100, null: false
    t.string "short_name", limit: 50, null: false
  end

  create_table "objects", primary_key: "object_id", id: { type: :integer, limit: 2, default: nil }, force: :cascade do |t|
    t.string "long_name", limit: 100, null: false
    t.string "short_name", limit: 50, null: false
  end

  create_table "osha_301_forms", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "physician_name"
    t.string "treatment_location"
    t.boolean "treated_in_er"
    t.boolean "hospitalized_overnight"
    t.string "case_number"
    t.date "date_of_injury"
    t.time "time_began_work", precision: 7
    t.time "time_of_event", precision: 7
    t.text "activity_before_incident"
    t.text "incident_description"
    t.text "injury_type"
    t.text "harmful_object"
    t.string "completed_by"
    t.string "completed_by_title"
    t.string "completed_by_phone"
    t.date "completion_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_osha_301_forms_on_event_id"
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
    t.bigint "event_id", null: false
    t.string "report_type"
    t.boolean "bloodborne_pathogen"
    t.string "job_title"
    t.string "work_hours"
    t.integer "hours_per_week"
    t.string "supervisor_name"
    t.string "supervisor_title"
    t.string "supervisor_email"
    t.string "supervisor_phone"
    t.string "form_completed_by"
    t.date "date_of_injury"
    t.time "time_of_injury", precision: 7
    t.text "injury_description"
    t.date "date_last_worked"
    t.date "date_returned_to_work"
    t.string "location_of_event"
    t.boolean "on_employers_premises"
    t.string "department_of_exposure"
    t.text "equipment_in_use"
    t.text "specific_activity"
    t.text "injury_sequence"
    t.string "physician_name"
    t.string "physician_address"
    t.string "physician_phone"
    t.string "hospital_name"
    t.string "hospital_address"
    t.string "hospital_phone"
    t.boolean "hospitalized_overnight"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_rm75_forms_on_event_id"
  end

  create_table "rm75i_forms", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "investigator_name"
    t.string "investigator_title"
    t.string "investigator_phone"
    t.boolean "osha_recordable"
    t.boolean "osha_reportable"
    t.text "incident_nature"
    t.text "incident_cause"
    t.text "root_cause"
    t.string "severity_potential"
    t.string "recurrence_probability"
    t.text "reportable_injury_codes"
    t.boolean "corrected_immediately"
    t.boolean "procedures_modified"
    t.string "responsible_person"
    t.string "responsible_title"
    t.string "responsible_department"
    t.string "responsible_phone"
    t.date "target_completion_date"
    t.date "actual_completion_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_rm75i_forms_on_event_id"
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

  create_table "tasks", primary_key: ["agency_id", "task_id"], force: :cascade do |t|
    t.string "agency_id", limit: 3, null: false
    t.string "task_id", limit: 4, null: false
    t.string "long_name", limit: 100, null: false
    t.string "short_name", limit: 50, null: false
  end

  create_table "units", primary_key: ["agency_id", "division_id", "department_id", "unit_id"], force: :cascade do |t|
    t.string "agency_id", limit: 3, null: false
    t.string "division_id", limit: 4, null: false
    t.string "department_id", limit: 4, null: false
    t.string "unit_id", limit: 4, null: false
    t.string "long_name", limit: 100, null: false
    t.string "short_name", limit: 50, null: false
  end

  add_foreign_key "BdmRates", "BdmRateTypes", column: "RateID", primary_key: "RateID", name: "FK_BdmRates_RateID"
  add_foreign_key "TC60", "TC60_Types", column: "TYPE", primary_key: "TYPE", name: "FK_TC60_TYPE_TC60_TYPES"
  add_foreign_key "events", "Employees", column: "employee_id", primary_key: "EmployeeID"
  add_foreign_key "events", "Employees", column: "reported_by_id", primary_key: "EmployeeID"
  add_foreign_key "loa_forms", "events"
  add_foreign_key "osha_301_forms", "events"
  add_foreign_key "parking_lot_vehicles", "parking_lot_submissions"
  add_foreign_key "rm75_forms", "events"
  add_foreign_key "rm75i_forms", "events"
end
