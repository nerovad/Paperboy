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

ActiveRecord::Schema[8.0].define(version: 2025_07_07_235310) do
  create_table "Agency", primary_key: "AgencyID", id: :integer, force: :cascade do |t|
    t.string "AgencyName", limit: 255, null: false
  end

  create_table "BDMRates", id: false, force: :cascade do |t|
    t.string "FYEAR", limit: 50
    t.integer "Unit", limit: 2
    t.integer "Object", limit: 2
    t.string "RateType", limit: 150
    t.string "UOM", limit: 50
    t.float "Rate"
  end

  create_table "BusinessUnit", id: :integer, default: 4641, force: :cascade do |t|
    t.varchar "name", limit: 50, null: false
  end

  create_table "CustomerAccount", id: false, force: :cascade do |t|
    t.varchar "CUNIT", limit: 4, null: false
    t.integer "COBJECT", null: false
    t.varchar "CACTIVITY", limit: 4
    t.varchar "CFUNCTION", limit: 4
    t.varchar "CPROGRAM", limit: 10
    t.varchar "CPHASE", limit: 6
    t.varchar "CTASK", limit: 4
  end

  create_table "CustomerAccountWithType", id: false, force: :cascade do |t|
    t.varchar "CUNIT", limit: 4, null: false
    t.integer "COBJECT", null: false
    t.varchar "CACTIVITY", limit: 4
    t.varchar "CFUNCTION", limit: 4
    t.varchar "CPROGRAM", limit: 10
    t.varchar "CPHASE", limit: 6
    t.varchar "CTASK", limit: 4
    t.varchar "TYPE", limit: 3
  end

  create_table "Department", primary_key: "DepartmentID", id: :integer, force: :cascade do |t|
    t.string "DepartmentName", limit: 255, null: false
    t.integer "DivisionID"
  end

  create_table "Division", primary_key: "DivisionID", id: :integer, force: :cascade do |t|
    t.string "DivisionName", limit: 255, null: false
    t.integer "AgencyID", null: false
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

  create_table "GL218-FY18", id: false, force: :cascade do |t|
    t.integer "BFY", limit: 2
    t.integer "Fiscal_Year", limit: 2
    t.money "Fund", precision: 19, scale: 4
    t.string "Dept", limit: 50
    t.integer "Unit", limit: 2
    t.integer "AP", limit: 1
    t.integer "Obj_Revenue", limit: 2
    t.string "Dept_Object", limit: 50
    t.string "Dept_Rev_Source", limit: 50
    t.string "Event_Type", limit: 50
    t.string "Event_Type_Name", limit: 150
    t.string "Posting_Code", limit: 50
    t.string "Posting_Code_Desc", limit: 50
    t.date "Doc_Record_Date"
    t.string "Jrnl_Doc_Code", limit: 50
    t.string "Jrnl_Doc_Dept_Code", limit: 50
    t.string "Jrnl_Doc_ID", limit: 50
    t.string "Vendor_Code", limit: 50
    t.string "Vendor_Invoice_No", limit: 50
    t.string "Vendor_Invoice_Date", limit: 50
    t.string "Vendor_Legal_Name", limit: 100
    t.string "Vendor_Alias_DBA_Name", limit: 100
    t.string "Accounting_Line_Desc", limit: 100
    t.money "Expense_Revenue_Amt", precision: 19, scale: 4
    t.string "Ref_Doc_ID", limit: 50
    t.string "Activity", limit: 50
    t.string "Function", limit: 50
    t.string "Major_Program", limit: 50
    t.string "Program_Code", limit: 50
    t.string "Phase_Code", limit: 50
    t.string "Task", limit: 50
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

  create_table "TC60_Activities", primary_key: ["Agency", "Activity"], force: :cascade do |t|
    t.string "Agency", limit: 3, null: false
    t.string "Activity", limit: 4, null: false
    t.string "ShortName", limit: 50, null: false
    t.string "LongName", limit: 100, null: false
  end

  create_table "TC60_Agencies", primary_key: "Agency", id: { type: :string, limit: 3 }, force: :cascade do |t|
    t.string "ShortName", limit: 50, null: false
    t.string "LongName", limit: 100, null: false
  end

  create_table "TC60_Departments", primary_key: ["Agency", "Division", "Department"], force: :cascade do |t|
    t.string "Agency", limit: 3, null: false
    t.string "Division", limit: 4, null: false
    t.string "Department", limit: 4, null: false
    t.string "ShortName", limit: 50, null: false
    t.string "LongName", limit: 100, null: false
  end

  create_table "TC60_Divisions", primary_key: ["Agency", "Division"], force: :cascade do |t|
    t.string "Agency", limit: 3, null: false
    t.string "Division", limit: 4, null: false
    t.string "ShortName", limit: 50, null: false
    t.string "LongName", limit: 100, null: false
  end

  create_table "TC60_Employees", primary_key: "EmployeeID", id: :integer, default: nil, force: :cascade do |t|
    t.string "FirstName", limit: 50, null: false
    t.string "LastName", limit: 50, null: false
    t.string "Email", limit: 50, null: false
    t.string "BU", limit: 4, null: false
  end

  create_table "TC60_Functions", primary_key: ["Agency", "Function"], force: :cascade do |t|
    t.string "Agency", limit: 3, null: false
    t.string "Function", limit: 4, null: false
    t.string "ShortName", limit: 50, null: false
    t.string "LongName", limit: 100, null: false
  end

  create_table "TC60_Functions_and_Funds", primary_key: ["Agency", "Name"], force: :cascade do |t|
    t.string "Agency", limit: 3, null: false
    t.string "Name", limit: 4, null: false
    t.string "ShortName", limit: 50, null: false
    t.string "LongName", limit: 100, null: false
  end

  create_table "TC60_Funds", primary_key: ["Agency", "Fund"], force: :cascade do |t|
    t.string "Agency", limit: 3, null: false
    t.string "Fund", limit: 4, null: false
    t.string "ShortName", limit: 50, null: false
    t.string "LongName", limit: 100, null: false
  end

  create_table "TC60_Major_Programs", primary_key: ["Agency", "MajorProgram"], force: :cascade do |t|
    t.string "Agency", limit: 3, null: false
    t.string "MajorProgram", limit: 10, null: false
    t.string "ShortName", limit: 50, null: false
    t.string "LongName", limit: 100, null: false
  end

  create_table "TC60_Objects", primary_key: "Object", id: :integer, default: nil, force: :cascade do |t|
    t.string "ShortName", limit: 50, null: false
    t.string "LongName", limit: 100, null: false
  end

  create_table "TC60_Phases", primary_key: ["Agency", "Phase"], force: :cascade do |t|
    t.string "Agency", limit: 3, null: false
    t.string "Phase", limit: 6, null: false
    t.string "ShortName", limit: 50, null: false
    t.string "LongName", limit: 100, null: false
  end

  create_table "TC60_Programs", primary_key: ["Agency", "Program"], force: :cascade do |t|
    t.string "Agency", limit: 3, null: false
    t.string "Program", limit: 10, null: false
    t.string "ShortName", limit: 50, null: false
    t.string "LongName", limit: 100, null: false
  end

  create_table "TC60_Revenues", primary_key: "Object", id: :integer, default: nil, force: :cascade do |t|
    t.string "ShortName", limit: 50, null: false
    t.string "LongName", limit: 100, null: false
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

  create_table "TC60_Tasks", primary_key: ["Agency", "Task"], force: :cascade do |t|
    t.string "Agency", limit: 3, null: false
    t.string "Task", limit: 4, null: false
    t.string "ShortName", limit: 50, null: false
    t.string "LongName", limit: 100, null: false
  end

  create_table "TC60_Types", primary_key: "TYPE", id: { type: :varchar, limit: 3 }, force: :cascade do |t|
    t.boolean "ACTIVE", null: false
    t.varchar "NAME", limit: 30
    t.varchar "funding_type", limit: 10, default: "monthly", null: false
    t.check_constraint "[funding_type]='both' OR [funding_type]='encumbered' OR [funding_type]='monthly'", name: "CK_TC60_Types_funding_type"
  end

  create_table "TC60_Units", primary_key: ["Agency", "Division", "Department", "Unit"], force: :cascade do |t|
    t.string "Agency", limit: 3, null: false
    t.string "Division", limit: 4, null: false
    t.string "Department", limit: 4, null: false
    t.string "Unit", limit: 4, null: false
    t.string "ShortName", limit: 50, null: false
    t.string "LongName", limit: 100, null: false
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

  create_table "parking_lot_submissions", force: :cascade do |t|
    t.string "name"
    t.string "phone"
    t.string "employee_id"
    t.string "email"
    t.string "agency"
    t.string "division"
    t.string "department"
    t.string "make"
    t.string "model"
    t.string "color"
    t.string "year"
    t.string "license_plate"
    t.string "parking_lot"
    t.string "old_permit_number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "unit"
    t.integer "status"
  end

  create_table "pc007", id: false, force: :cascade do |t|
    t.integer "FYEAR", limit: 2
    t.integer "APMON", limit: 1
    t.date "ENC_DATE"
    t.string "DEPT", limit: 50
    t.integer "DIV", limit: 2
    t.string "DIVISION_NAME", limit: 50
    t.integer "UNIT", limit: 2
    t.string "UNIT_NAME", limit: 50
    t.string "FUND", limit: 50
    t.string "FUND_NAME", limit: 50
    t.string "DOC_TYPE", limit: 50
    t.string "DOC_CODE", limit: 50
    t.string "DOCUMENT_ID", limit: 50
    t.string "DOC_ID_VALUE", limit: 50
    t.integer "LN", limit: 1
    t.string "LN_DSCR", limit: 100
    t.string "REF_DOC_CODE", limit: 50
    t.string "REF_DOC_DEPT_CODE", limit: 50
    t.string "REF_DOC_ID", limit: 50
    t.string "VENDOR_NM", limit: 50
    t.string "VENDOR_NAME", limit: 50
    t.string "ACTV", limit: 50
    t.string "FUNC", limit: 50
    t.integer "OBJ", limit: 2
    t.string "OBJ_NM", limit: 100
    t.string "PROG", limit: 50
    t.string "PHASE", limit: 50
    t.float "ENC_AMOUNT"
    t.float "CLOSED_AMOUNT"
    t.float "OS_AMT"
  end

  add_foreign_key "Department", "Division", column: "DivisionID", primary_key: "DivisionID", name: "FK__Departmen__Divis__54968AE5"
  add_foreign_key "Division", "Agency", column: "AgencyID", primary_key: "AgencyID", name: "FK__Division__Agency__51BA1E3A"
  add_foreign_key "TC60", "TC60_Types", column: "TYPE", primary_key: "TYPE", name: "FK_TC60_TYPE_TC60_TYPES"
  add_foreign_key "TC60_Activities", "TC60_Agencies", column: "Agency", primary_key: "Agency", name: "fk_tc60_activities_tc60_agencies"
  add_foreign_key "TC60_Departments", "TC60_Divisions", column: ["Agency", "Division"], primary_key: ["Agency", "Division"], name: "FK_TC60_Departments_TC60_Divisions"
  add_foreign_key "TC60_Divisions", "TC60_Agencies", column: "Agency", primary_key: "Agency", name: "FK_TC60_Divisions_TC60_Agencies"
  add_foreign_key "TC60_Functions", "TC60_Agencies", column: "Agency", primary_key: "Agency", name: "fk_tc60_functions_tc60_agencies"
  add_foreign_key "TC60_Functions_and_Funds", "TC60_Agencies", column: "Agency", primary_key: "Agency", name: "fk_tc60_functions_and_funds_tc60_agencies"
  add_foreign_key "TC60_Funds", "TC60_Agencies", column: "Agency", primary_key: "Agency", name: "fk_tc60_funds_tc60_agencies"
  add_foreign_key "TC60_Major_Programs", "TC60_Agencies", column: "Agency", primary_key: "Agency", name: "FK_TC60_MajorProgram_TC60_Agencies"
  add_foreign_key "TC60_Phases", "TC60_Agencies", column: "Agency", primary_key: "Agency", name: "fk_tc60_phases_tc60_agencies"
  add_foreign_key "TC60_Programs", "TC60_Agencies", column: "Agency", primary_key: "Agency", name: "fk_tc60_programs_tc60_agencies"
  add_foreign_key "TC60_Tasks", "TC60_Agencies", column: "Agency", primary_key: "Agency", name: "fk_tc60_tasks_tc60_agencies"
  add_foreign_key "TC60_Units", "TC60_Departments", column: ["Agency", "Division", "Department"], primary_key: ["Agency", "Division", "Department"], name: "FK_TC60_Units_TC60_Departments"
end
