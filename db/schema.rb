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

ActiveRecord::Schema[8.0].define(version: 2026_02_09_233503) do
  create_table "AimUsers", id: false, force: :cascade do |t|
    t.integer "EmployeeID", null: false
    t.string "FirstName", limit: 50, null: false
    t.string "LastName", limit: 50, null: false
    t.string "email", limit: 50, null: false
    t.date "Created", null: false
    t.date "Updated", null: false
    t.date "LastLogin", null: false
    t.string "Active", limit: 50, null: false
    t.string "LicenseType", limit: 50, null: false
    t.string "SystemAdmininistrator", limit: 50, null: false
    t.boolean "ApplicationAdministrator", null: false
    t.boolean "ApplicationSupervisor", null: false
    t.string "ExternalAdministrator", limit: 50, null: false
    t.string "ExternalSupervisor", limit: 50, null: false
  end

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

  create_table "Employee_Groups", primary_key: ["EmployeeID", "GroupID"], force: :cascade do |t|
    t.integer "EmployeeID", null: false
    t.integer "GroupID", null: false
    t.datetime "Assigned_At", precision: nil, default: -> { "getdate()" }
    t.integer "Assigned_By"
  end

  create_table "Employees", primary_key: "EmployeeID", id: :integer, default: nil, force: :cascade do |t|
    t.string "Last_Name", limit: 50
    t.string "First_Name", limit: 50
    t.string "Job_Title", limit: 50
    t.string "Work_Phone", limit: 50
    t.string "Agency", limit: 50
    t.string "Unit", limit: 50
    t.string "Job_Code", limit: 50
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

  create_table "Employees_Old", primary_key: "EmployeeID", id: :integer, default: nil, force: :cascade do |t|
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

  create_table "GL218Detail", id: false, force: :cascade do |t|
    t.integer "BFY"
    t.integer "FY"
    t.string "Fund", limit: 4
    t.string "Dept", limit: 3
    t.string "Division", limit: 4
    t.string "Unit", limit: 4
    t.integer "AP"
    t.integer "Obj_Revenue"
    t.string "Obj_Revenue_Name", limit: 100
    t.string "Dept_Object", limit: 100
    t.string "Dept_Rev_Source", limit: 100
    t.string "Event_Type", limit: 4
    t.string "Event_Type_Name", limit: 100
    t.string "Posting_Code", limit: 4
    t.string "Posting_Code_Desc", limit: 100
    t.date "Doc_Record_Date"
    t.string "Jrnl_Doc_Code", limit: 6
    t.string "Jrnl_Doc_Dept_Code", limit: 3
    t.string "Jrnl_Doc_ID", limit: 100
    t.string "Vendor_Code", limit: 100
    t.string "Vendor_Invoice_No", limit: 100
    t.datetime "Vendor_Invoice_Date", precision: nil
    t.string "Vendor_Legal_Name", limit: 100
    t.string "Vendor_Alias_DBA_Name", limit: 100
    t.string "Accounting_Line_Desc", limit: 100
    t.float "Expense_Revenue_Amt"
    t.string "Ref_Doc_ID", limit: 100
    t.string "Activity", limit: 4
    t.string "Function", limit: 4
    t.string "Major_Program", limit: 10
    t.string "Program_Code", limit: 10
    t.string "Phase_Code", limit: 6
    t.string "Task", limit: 4
  end

  create_table "Groups", primary_key: "GroupID", id: :integer, force: :cascade do |t|
    t.string "Group_Name", limit: 100, null: false
    t.string "Description", limit: 500
    t.datetime "Created_At", precision: nil, default: -> { "getdate()" }
  end

  create_table "Manual_Transactions", id: false, force: :cascade do |t|
    t.string "TYPE", limit: 3
    t.string "CUNIT", limit: 4
    t.string "COBJECT", limit: 4
    t.string "CACTIVITY", limit: 4
    t.string "CFUNCTION", limit: 4
    t.string "CPROGRAM", limit: 10
    t.string "CPHASE", limit: 6
    t.string "CTASK", limit: 4
    t.float "AMOUNT", default: 0.0
    t.string "SUNIT", limit: 4
    t.string "SOBJECT", limit: 4
    t.string "SACTIVITY", limit: 4
    t.string "SFUNCTION", limit: 4
    t.string "SPROGRAM", limit: 10
    t.string "SPHASE", limit: 6
    t.string "STASK", limit: 4
    t.string "POSTING_REF", limit: 20
    t.string "SERVICE", limit: 15
    t.date "DATE"
    t.string "DOC_NMBR", limit: 50
    t.string "DESCRIPTION", limit: 100
    t.string "OTHER1", limit: 50
    t.string "OTHER2", limit: 50
    t.string "OTHER3", limit: 50
    t.float "QUANTITY", default: 0.0
    t.float "RATE", default: 0.0
    t.float "COST", default: 0.0
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

  create_table "TC60_Adjustments", id: false, force: :cascade do |t|
    t.varchar "TYPE", limit: 3, null: false
    t.varchar "CUNIT", limit: 4, null: false
    t.integer "COBJECT", null: false
    t.varchar "CACTIVITY", limit: 4
    t.varchar "CFUNCTION", limit: 4
    t.varchar "CPROGRAM", limit: 10
    t.varchar "CPHASE", limit: 6
    t.varchar "CTASK", limit: 4
    t.float "AMOUNT"
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
    t.float "QUANTITY"
    t.float "RATE"
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "form_template_status_id"
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
    t.string "org_scope_type"
    t.string "org_scope_id"
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approver_id"], name: "index_osha301_forms_on_approver_id"
    t.index ["employee_id"], name: "index_osha301_forms_on_employee_id"
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
    t.index ["approver_id"], name: "index_rm75_forms_on_approver_id"
    t.index ["employee_id"], name: "index_rm75_forms_on_employee_id"
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

  add_foreign_key "BdmRates", "BdmRateTypes", column: "RateID", primary_key: "RateID", name: "FK_BdmRates_RateID"
  add_foreign_key "Employee_Groups", "Employees", column: "EmployeeID", primary_key: "EmployeeID", name: "FK__Employee___Emplo__5B988E2F"
  add_foreign_key "Employee_Groups", "Groups", column: "GroupID", primary_key: "GroupID", name: "FK__Employee___Group__5C8CB268"
  add_foreign_key "TC60", "TC60_Types", column: "TYPE", primary_key: "TYPE", name: "FK_TC60_TYPE_TC60_TYPES"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "form_fields", "form_templates"
  add_foreign_key "form_template_routing_steps", "form_template_statuses"
  add_foreign_key "form_template_routing_steps", "form_templates"
  add_foreign_key "form_template_statuses", "form_templates"
  add_foreign_key "parking_lot_vehicles", "parking_lot_submissions"
end
