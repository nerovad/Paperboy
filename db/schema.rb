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

ActiveRecord::Schema[8.1].define(version: 2026_10_10_221750) do
  create_schema "aim"

  create_table "Employee_Groups", force: :cascade do |t|
    t.datetime "Assigned_At", precision: nil, default: -> { "getdate()" }
    t.integer "Assigned_By"
    t.integer "EmployeeID", null: false
    t.bigint "GroupID", null: false
    t.index ["EmployeeID", "GroupID"], name: "idx_employee_groups_on_employee_group", unique: true
  end

  create_table "Group_Permissions", primary_key: ["GroupID", "Permission_Type", "Permission_Key"], force: :cascade do |t|
    t.datetime "Created_At", default: -> { "getdate()" }, null: false
    t.integer "GroupID", null: false
    t.string "Permission_Key", limit: 255, null: false
    t.string "Permission_Type", limit: 50, null: false
  end

  create_table "Groups", primary_key: "GroupID", id: :integer, force: :cascade do |t|
    t.datetime "Created_At", precision: nil, default: -> { "getdate()" }
    t.string "Description", limit: 500
    t.string "Group_Name", limit: 100, null: false
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
  end

  create_table "aim.coding_imports", force: :cascade do |t|
    t.string "agency", limit: 3, null: false
    t.datetime "created_at", null: false
    t.string "default_unit", limit: 10
    t.date "effective_from"
    t.string "effective_option", limit: 20, null: false
    t.text "file_content"
    t.string "file_name", limit: 260, null: false
    t.string "imported_by", limit: 255, null: false
    t.integer "loaded_count", default: 0, null: false
    t.integer "refused_count", default: 0, null: false
    t.text "report"
    t.integer "retired_count", default: 0, null: false
    t.integer "row_count", default: 0, null: false
    t.string "status", limit: 20, default: "applied", null: false
    t.datetime "undone_at"
    t.string "undone_by", limit: 255
    t.datetime "updated_at", null: false
  end

  create_table "aim.coding_lines", force: :cascade do |t|
    t.string "activity", limit: 20
    t.decimal "amount", precision: 15, scale: 2
    t.bigint "coding_rule_id"
    t.datetime "created_at", null: false
    t.string "department", limit: 20
    t.string "dept_object", limit: 20
    t.string "encumbrance_number", limit: 100
    t.string "encumbrance_type", limit: 10
    t.string "function_code", limit: 20
    t.string "fund", limit: 20
    t.bigint "invoice_id", null: false
    t.integer "line_no", default: 1, null: false
    t.string "ma_number", limit: 100
    t.string "major_program", limit: 20
    t.string "object_code", limit: 20
    t.string "org_number", limit: 20
    t.string "phase", limit: 20
    t.string "program", limit: 20
    t.string "set_by", limit: 255
    t.string "source", limit: 20, default: "person", null: false
    t.string "task", limit: 20
    t.datetime "updated_at", null: false
    t.string "vendor_code", limit: 50
    t.text "warnings"
    t.index ["invoice_id", "line_no"], name: "index_aim_coding_lines_on_invoice_and_line", unique: true
  end

  create_table "aim.coding_rule_changes", force: :cascade do |t|
    t.text "after"
    t.text "before"
    t.string "changed_by", limit: 255, null: false
    t.bigint "coding_rule_id", null: false
    t.datetime "created_at", null: false
    t.string "field", limit: 40
    t.string "kind", limit: 20, null: false
    t.index ["coding_rule_id", "created_at"], name: "index_aim_coding_rule_changes_on_rule_and_time"
  end

  create_table "aim.coding_rules", force: :cascade do |t|
    t.string "activity", limit: 20
    t.string "agency", limit: 3, null: false
    t.string "budget_unit", limit: 10, null: false
    t.datetime "created_at", null: false
    t.string "created_by", limit: 255
    t.string "customer_number", limit: 100
    t.string "department", limit: 20
    t.string "dept_object", limit: 20
    t.date "effective_from", null: false
    t.date "effective_until"
    t.string "encumbrance_number", limit: 100
    t.string "encumbrance_type", limit: 10
    t.string "function_code", limit: 20
    t.string "fund", limit: 20
    t.bigint "import_id"
    t.string "ma_number", limit: 100
    t.string "major_program", limit: 20
    t.text "notes"
    t.string "object_code", limit: 20
    t.string "phase", limit: 20
    t.string "program", limit: 20
    t.bigint "retired_by_import_id"
    t.integer "source_row"
    t.string "task", limit: 20
    t.datetime "updated_at", null: false
    t.string "updated_by", limit: 255
    t.string "vendor_code", limit: 50
    t.string "vendor_key", limit: 255, null: false
    t.string "vendor_name", limit: 255, null: false
    t.text "warnings"
    t.index ["agency", "budget_unit", "vendor_key"], name: "index_aim_coding_rules_on_agency_unit_vendor"
    t.index ["import_id"], name: "index_aim_coding_rules_on_import_id"
    t.index ["retired_by_import_id"], name: "index_aim_coding_rules_on_retired_by_import_id"
    t.index ["vendor_key"], name: "index_aim_coding_rules_on_vendor_key"
  end

  create_table "aim.enabled_units", force: :cascade do |t|
    t.string "agency_id", limit: 10, null: false
    t.datetime "created_at", null: false
    t.string "enabled_by", limit: 255
    t.string "unit_id", limit: 10
    t.datetime "updated_at", null: false
    t.index ["agency_id", "unit_id"], name: "index_aim_enabled_units_on_agency_and_unit", unique: true
  end

  create_table "aim.fiscal_records", force: :cascade do |t|
    t.datetime "archived_at"
    t.date "check_date"
    t.string "check_number", limit: 50
    t.datetime "created_at", null: false
    t.decimal "credit_amount", precision: 15, scale: 2
    t.text "description"
    t.datetime "exported_at"
    t.string "hold_reason", limit: 500
    t.bigint "invoice_id", null: false
    t.string "pay_doc_number", limit: 100
    t.string "stamp_error", limit: 500
    t.datetime "stamped_at"
    t.string "status", limit: 20, default: "review", null: false
    t.string "tags", limit: 500
    t.datetime "updated_at", null: false
    t.string "updated_by", limit: 255
    t.index ["invoice_id"], name: "index_aim_fiscal_records_on_invoice_id", unique: true
    t.index ["status"], name: "index_aim_fiscal_records_on_status"
  end

  create_table "aim.invoice_events", force: :cascade do |t|
    t.string "action", limit: 50, null: false
    t.string "actor", null: false
    t.datetime "created_at", null: false
    t.string "from_state", limit: 50
    t.bigint "invoice_id", null: false
    t.text "note"
    t.string "to_state", limit: 50
    t.index ["invoice_id", "created_at"], name: "index_aim_invoice_events_on_invoice_id_and_created_at"
  end

  create_table "aim.invoices", force: :cascade do |t|
    t.string "agency", limit: 3
    t.integer "assigned_employee_id"
    t.string "assigned_to"
    t.string "assignment_source", limit: 50
    t.integer "attempt", default: 0, null: false
    t.string "batch_id", limit: 255, null: false
    t.string "billed_state", limit: 40
    t.string "budget_unit", limit: 10
    t.string "business_key", limit: 450
    t.datetime "claimed_at"
    t.string "claimed_by"
    t.string "claimed_by_name"
    t.datetime "coded_at"
    t.string "command", limit: 20
    t.string "content_hash", limit: 64
    t.datetime "created_at", null: false
    t.string "customer_number", limit: 100
    t.string "document_type", limit: 50
    t.datetime "exported_at"
    t.text "extracted"
    t.string "extracted_vendor_name"
    t.boolean "high_confidence"
    t.date "invoice_date"
    t.string "invoice_number", limit: 100
    t.decimal "invoice_total", precision: 15, scale: 2
    t.string "lease_owner", limit: 100
    t.datetime "lease_until"
    t.text "manifest"
    t.text "notes"
    t.string "order_number", limit: 100
    t.integer "page_count"
    t.bigint "parent_id"
    t.text "review_note"
    t.string "review_reason", limit: 40
    t.decimal "sales_tax", precision: 15, scale: 2
    t.string "source_filename", limit: 260
    t.string "source_path", limit: 1000
    t.boolean "split_check", default: true, null: false
    t.string "state", limit: 50, null: false
    t.string "submitter"
    t.decimal "subtotal", precision: 15, scale: 2
    t.datetime "updated_at", null: false
    t.string "vendor_name"
    t.index ["assigned_employee_id"], name: "index_aim_invoices_on_assigned_employee_id"
    t.index ["batch_id"], name: "index_aim_invoices_on_batch_id", unique: true
    t.index ["coded_at"], name: "index_aim_invoices_on_coded_at"
    t.index ["command", "lease_until"], name: "index_aim_invoices_on_command_and_lease_until"
    t.index ["content_hash"], name: "index_aim_invoices_on_content_hash"
    t.index ["parent_id"], name: "index_aim_invoices_on_parent_id"
    t.index ["state", "budget_unit"], name: "index_aim_invoices_on_state_and_budget_unit"
  end

  create_table "aim.members", force: :cascade do |t|
    t.string "added_by", limit: 255
    t.datetime "created_at", null: false
    t.datetime "deactivated_at"
    t.string "deactivated_by", limit: 255
    t.string "deactivation_reason", limit: 500
    t.integer "employee_id", null: false
    t.boolean "fiscal", default: false, null: false
    t.string "fusion_roles", limit: 255
    t.string "fusion_team", limit: 100
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_aim_members_on_employee_id", unique: true
  end

  create_table "aim.user_budget_units", force: :cascade do |t|
    t.boolean "bu_admin", default: false, null: false
    t.string "budget_unit", limit: 10, null: false
    t.datetime "created_at", null: false
    t.integer "employee_id", null: false
    t.string "granted_by", limit: 255
    t.boolean "hidden", default: false, null: false
    t.boolean "shared_queue", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["budget_unit"], name: "index_aim_user_budget_units_on_budget_unit"
    t.index ["employee_id", "budget_unit"], name: "index_aim_user_budget_units_on_person_and_bu", unique: true
  end

  create_table "aim.user_preferences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "employee_id", null: false
    t.string "start_mode", limit: 20, default: "admin", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_aim_user_preferences_on_employee_id", unique: true
  end

  create_table "aim.vendor_aliases", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "extracted_name", limit: 255, null: false
    t.string "learned_by", limit: 255
    t.string "normalized_name", limit: 255, null: false
    t.string "note", limit: 500
    t.datetime "updated_at", null: false
    t.index ["extracted_name"], name: "index_aim_vendor_aliases_on_extracted_name", unique: true
    t.index ["normalized_name"], name: "index_aim_vendor_aliases_on_normalized_name"
  end

  create_table "aim.vendor_rules", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "rules", null: false
    t.datetime "updated_at", null: false
    t.string "updated_by", limit: 255
    t.string "vendor_name", limit: 255, null: false
    t.index ["vendor_name"], name: "index_aim_vendor_rules_on_vendor_name", unique: true
  end

  create_table "authorization_fos", force: :cascade do |t|
    t.string "agency"
    t.datetime "created_at", null: false
    t.string "department"
    t.string "division"
    t.string "email"
    t.string "employee_id"
    t.string "name"
    t.string "phone"
    t.string "unit"
    t.datetime "updated_at", null: false
  end

  create_table "authorization_managers", force: :cascade do |t|
    t.string "assigned_by"
    t.datetime "created_at", null: false
    t.string "department_id", null: false
    t.string "employee_id", null: false
    t.datetime "removed_at"
    t.string "removed_by"
    t.datetime "updated_at", null: false
  end

  create_table "authorized_approver_changes", force: :cascade do |t|
    t.string "action", null: false
    t.string "changed_by", null: false
    t.datetime "created_at", null: false
    t.string "department_id", null: false
    t.string "employee_id", null: false
    t.text "scope_after"
    t.text "scope_before"
    t.index ["department_id", "created_at"], name: "idx_on_department_id_created_at_2976d118e9"
  end

  create_table "authorized_approvers", force: :cascade do |t|
    t.boolean "all_budget_units", default: false, null: false
    t.boolean "all_locations", default: false, null: false
    t.string "authorized_by"
    t.text "budget_units"
    t.datetime "created_at", null: false
    t.string "department_id", null: false
    t.string "employee_id", null: false
    t.string "key_type"
    t.text "locations"
    t.string "service_type", null: false
    t.datetime "updated_at", null: false
  end

  create_table "away_periods", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "delegate_id", null: false
    t.string "employee_id", null: false
    t.date "ends_on", null: false
    t.date "starts_on", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id", "starts_on", "ends_on"], name: "index_away_periods_on_employee_and_dates"
    t.index ["ends_on"], name: "index_away_periods_on_ends_on"
  end

  create_table "bike_locker_forms", force: :cascade do |t|
    t.string "agency"
    t.string "approver_id"
    t.datetime "created_at", null: false
    t.text "deny_reason"
    t.string "department"
    t.string "division"
    t.string "email"
    t.string "employee_id"
    t.bigint "locker_id"
    t.string "locker_location"
    t.string "locker_number"
    t.string "name"
    t.integer "number_of_bikes"
    t.string "phone"
    t.string "status", default: "in_progress", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
    t.index ["approver_id"], name: "index_bike_locker_forms_on_approver_id"
    t.index ["employee_id"], name: "index_bike_locker_forms_on_employee_id"
    t.index ["locker_id"], name: "index_bike_locker_forms_on_locker_id"
  end

  create_table "bike_locker_lots", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_bike_locker_lots_on_name", unique: true
  end

  create_table "bike_lockers", force: :cascade do |t|
    t.datetime "assigned_at"
    t.string "assigned_employee_id"
    t.datetime "created_at", null: false
    t.integer "locker_number", null: false
    t.bigint "lot_id", null: false
    t.string "status", default: "available", null: false
    t.datetime "updated_at", null: false
    t.index ["lot_id", "locker_number"], name: "index_bike_lockers_on_lot_id_and_locker_number", unique: true
    t.index ["lot_id", "status"], name: "index_bike_lockers_on_lot_id_and_status"
    t.index ["lot_id"], name: "index_bike_lockers_on_lot_id"
  end

  create_table "carpool_forms", force: :cascade do |t|
    t.string "agency"
    t.string "approver_id"
    t.datetime "created_at", null: false
    t.string "department"
    t.string "division"
    t.string "email"
    t.string "employee_id"
    t.string "name"
    t.string "phone"
    t.string "status", default: "in_progress", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
  end

  create_table "contractors", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "agency"
    t.datetime "created_at", null: false
    t.string "department"
    t.string "email", null: false
    t.datetime "expires_at"
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "password_digest"
    t.integer "supervisor_id"
    t.string "unit"
    t.datetime "updated_at", null: false
    t.string "work_phone"
    t.index ["email"], name: "index_contractors_on_email", unique: true
  end

  create_table "creative_job_requests", force: :cascade do |t|
    t.string "asset_type"
    t.datetime "created_at", null: false
    t.date "date"
    t.text "description"
    t.string "employee_name"
    t.string "job_agency"
    t.string "job_department"
    t.string "job_division"
    t.string "job_id"
    t.string "job_title"
    t.string "job_type"
    t.string "job_unit"
    t.string "location"
    t.datetime "updated_at", null: false
  end

  create_table "critical_information_authorizations", force: :cascade do |t|
    t.string "authorized_by"
    t.datetime "created_at", null: false
    t.string "employee_id", null: false
    t.string "location", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_critical_information_authorizations_on_employee_id"
    t.index ["location"], name: "index_critical_information_authorizations_on_location", unique: true
  end

  create_table "critical_information_locations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "created_by"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_critical_information_locations_on_name", unique: true
  end

  create_table "critical_information_reportings", force: :cascade do |t|
    t.datetime "actual_completion_date"
    t.string "agency"
    t.string "assigned_manager_id"
    t.string "building"
    t.text "cause"
    t.datetime "created_at", null: false
    t.string "department"
    t.string "division"
    t.string "email"
    t.string "employee_id"
    t.string "impact"
    t.datetime "impact_started"
    t.string "impacted_agency"
    t.string "impacted_customers"
    t.string "impacted_employee"
    t.text "incident_details"
    t.string "incident_type"
    t.string "location"
    t.string "name"
    t.text "next_steps"
    t.string "other_building"
    t.string "phone"
    t.text "staff_involved"
    t.string "status", default: "in_progress", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
    t.string "urgency"
  end

  create_table "dam_access_rule_grantees", force: :cascade do |t|
    t.string "agency_id"
    t.datetime "created_at", null: false
    t.string "department_id"
    t.string "division_id"
    t.string "employee_id"
    t.string "grantee_type", null: false
    t.integer "group_id"
    t.bigint "rule_id", null: false
    t.string "unit_id"
    t.index ["grantee_type", "employee_id"], name: "index_dam_access_rule_grantees_on_grantee_type_and_employee_id"
    t.index ["grantee_type", "group_id"], name: "index_dam_access_rule_grantees_on_grantee_type_and_group_id"
    t.index ["rule_id"], name: "index_dam_access_rule_grantees_on_rule_id"
  end

  create_table "dam_access_rules", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "agency_id"
    t.boolean "can_download", default: false, null: false
    t.boolean "can_edit", default: false, null: false
    t.boolean "can_publish", default: false, null: false
    t.boolean "can_share", default: false, null: false
    t.text "conditions"
    t.datetime "created_at", null: false
    t.string "created_by_id"
    t.string "created_by_name"
    t.string "department_id"
    t.text "description"
    t.string "division_id"
    t.string "name", null: false
    t.string "unit_id"
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_dam_access_rules_on_active"
  end

  create_table "dam_assets", force: :cascade do |t|
    t.string "agency_id"
    t.bigint "byte_size"
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "department_id"
    t.text "derivative_error"
    t.string "derivative_state", default: "pending", null: false
    t.text "description"
    t.string "division_id"
    t.integer "duration_seconds"
    t.string "external_ref"
    t.string "filename"
    t.string "format"
    t.integer "height"
    t.datetime "ingested_at"
    t.string "media_type", default: "other", null: false
    t.string "source_key", limit: 64
    t.string "source_path"
    t.string "status", default: "active", null: false
    t.string "storage_kind", default: "stored", null: false
    t.bigint "storage_location_id"
    t.string "storage_path"
    t.string "title", null: false
    t.string "unit_id"
    t.datetime "updated_at", null: false
    t.string "uploaded_by_id"
    t.string "uploaded_by_name"
    t.integer "width"
    t.index ["agency_id"], name: "index_dam_assets_on_agency_id"
    t.index ["created_at"], name: "index_dam_assets_on_created_at"
    t.index ["format"], name: "index_dam_assets_on_format"
    t.index ["media_type"], name: "index_dam_assets_on_media_type"
    t.index ["status"], name: "index_dam_assets_on_status"
    t.index ["storage_location_id", "external_ref"], name: "index_dam_assets_on_location_and_external_ref", unique: true, where: "([external_ref] IS NOT NULL)"
    t.index ["storage_location_id", "source_key"], name: "index_dam_assets_on_location_and_source", unique: true, where: "([source_key] IS NOT NULL)"
    t.index ["storage_location_id"], name: "index_dam_assets_on_storage_location_id"
    t.index ["uploaded_by_id"], name: "index_dam_assets_on_uploaded_by_id"
  end

  create_table "dam_collection_assets", force: :cascade do |t|
    t.string "added_by_id"
    t.bigint "asset_id", null: false
    t.bigint "collection_id", null: false
    t.datetime "created_at", null: false
    t.integer "position", default: 0, null: false
    t.index ["asset_id"], name: "index_dam_collection_assets_on_asset_id"
    t.index ["collection_id", "asset_id"], name: "index_dam_collection_assets_on_collection_id_and_asset_id", unique: true
    t.index ["collection_id"], name: "index_dam_collection_assets_on_collection_id"
  end

  create_table "dam_collections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "created_by_id"
    t.string "created_by_name"
    t.text "description"
    t.string "external_ref"
    t.string "name", null: false
    t.bigint "parent_id"
    t.datetime "updated_at", null: false
    t.index ["external_ref"], name: "index_dam_collections_on_external_ref", unique: true, where: "([external_ref] IS NOT NULL)"
    t.index ["name"], name: "index_dam_collections_on_name"
    t.index ["parent_id"], name: "index_dam_collections_on_parent_id"
  end

  create_table "dam_favorites", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "employee_id", null: false
    t.bigint "favoritable_id", null: false
    t.string "favoritable_type", null: false
    t.index ["employee_id", "favoritable_type", "favoritable_id"], name: "index_dam_favorites_on_employee_and_subject", unique: true
  end

  create_table "dam_ingest_failures", force: :cascade do |t|
    t.integer "attempts", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "last_failed_at"
    t.text "reason"
    t.string "source_key", limit: 64, null: false
    t.string "source_path"
    t.bigint "storage_location_id", null: false
    t.datetime "updated_at", null: false
    t.index ["storage_location_id", "source_key"], name: "index_dam_ingest_failures_on_location_and_source", unique: true
    t.index ["storage_location_id"], name: "index_dam_ingest_failures_on_storage_location_id"
  end

  create_table "dam_jobs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "created_by_id"
    t.string "created_by_name"
    t.text "error_message"
    t.datetime "finished_at"
    t.string "job_type", null: false
    t.text "log"
    t.integer "processed_items", default: 0, null: false
    t.datetime "queued_at"
    t.datetime "started_at"
    t.string "status", default: "queued", null: false
    t.bigint "subject_id"
    t.string "subject_label"
    t.string "subject_type"
    t.integer "total_items", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "workflow_id"
    t.index ["created_at"], name: "index_dam_jobs_on_created_at"
    t.index ["job_type"], name: "index_dam_jobs_on_job_type"
    t.index ["status"], name: "index_dam_jobs_on_status"
    t.index ["subject_type", "subject_id"], name: "index_dam_jobs_on_subject_type_and_subject_id"
    t.index ["workflow_id"], name: "index_dam_jobs_on_workflow_id"
  end

  create_table "dam_metadata_fields", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "field_type", default: "text", null: false
    t.string "key", null: false
    t.string "label", null: false
    t.text "options"
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_dam_metadata_fields_on_key", unique: true
  end

  create_table "dam_metadata_values", force: :cascade do |t|
    t.bigint "asset_id", null: false
    t.datetime "created_at", null: false
    t.datetime "date_value"
    t.string "field_key", null: false
    t.decimal "numeric_value", precision: 18, scale: 4
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["asset_id", "field_key"], name: "index_dam_metadata_values_on_asset_id_and_field_key", unique: true
    t.index ["asset_id"], name: "index_dam_metadata_values_on_asset_id"
    t.index ["field_key"], name: "index_dam_metadata_values_on_field_key"
  end

  create_table "dam_publications", force: :cascade do |t|
    t.bigint "asset_id", null: false
    t.string "asset_title"
    t.integer "attempts", default: 0, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.text "error"
    t.string "external_id"
    t.string "external_url"
    t.datetime "finished_at"
    t.integer "job_id"
    t.text "log"
    t.string "privacy"
    t.string "provider"
    t.string "public_token"
    t.bigint "publish_target_id", null: false
    t.datetime "queued_at"
    t.string "requested_by_id"
    t.string "requested_by_name"
    t.integer "response_code"
    t.datetime "started_at"
    t.string "status", default: "queued", null: false
    t.string "tags"
    t.string "target_label"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["asset_id"], name: "index_dam_publications_on_asset_id"
    t.index ["created_at"], name: "index_dam_publications_on_created_at"
    t.index ["public_token"], name: "index_dam_publications_on_public_token", unique: true, where: "([public_token] IS NOT NULL)"
    t.index ["publish_target_id"], name: "index_dam_publications_on_publish_target_id"
    t.index ["requested_by_id"], name: "index_dam_publications_on_requested_by_id"
    t.index ["status"], name: "index_dam_publications_on_status"
  end

  create_table "dam_publish_targets", force: :cascade do |t|
    t.string "account_label"
    t.string "account_ref"
    t.string "body_style", default: "multipart", null: false
    t.datetime "connected_at"
    t.string "connected_by_id"
    t.string "connected_by_name"
    t.datetime "created_at", null: false
    t.string "default_privacy"
    t.boolean "enabled", default: true, null: false
    t.string "endpoint_url"
    t.string "file_field", default: "file", null: false
    t.text "headers"
    t.string "http_method", default: "POST", null: false
    t.string "key", null: false
    t.string "label", null: false
    t.datetime "last_published_at"
    t.text "notes"
    t.text "oauth_access_token"
    t.datetime "oauth_expires_at"
    t.text "oauth_refresh_token"
    t.string "oauth_scope"
    t.integer "position", default: 0, null: false
    t.string "provider", null: false
    t.datetime "updated_at", null: false
    t.index ["enabled"], name: "index_dam_publish_targets_on_enabled"
    t.index ["key"], name: "index_dam_publish_targets_on_key", unique: true
    t.index ["provider"], name: "index_dam_publish_targets_on_provider"
  end

  create_table "dam_recent_views", force: :cascade do |t|
    t.string "employee_id", null: false
    t.integer "view_count", default: 1, null: false
    t.bigint "viewable_id", null: false
    t.string "viewable_type", null: false
    t.datetime "viewed_at", null: false
    t.index ["employee_id", "viewable_type", "viewable_id"], name: "index_dam_recent_views_on_employee_and_subject", unique: true
    t.index ["employee_id", "viewed_at"], name: "index_dam_recent_views_on_employee_id_and_viewed_at"
  end

  create_table "dam_shares", force: :cascade do |t|
    t.integer "access_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.datetime "last_accessed_at"
    t.text "message"
    t.string "permission", default: "view", null: false
    t.text "recipients"
    t.datetime "revoked_at"
    t.string "shared_by_id"
    t.string "shared_by_name"
    t.bigint "subject_id", null: false
    t.string "subject_label"
    t.string "subject_type", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_dam_shares_on_created_at"
    t.index ["shared_by_id"], name: "index_dam_shares_on_shared_by_id"
    t.index ["subject_type", "subject_id"], name: "index_dam_shares_on_subject_type_and_subject_id"
    t.index ["token"], name: "index_dam_shares_on_token", unique: true
  end

  create_table "dam_storage_locations", force: :cascade do |t|
    t.string "accepted_formats"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.boolean "default_for_uploads", default: false, null: false
    t.text "description"
    t.string "ignore_patterns"
    t.string "ingest_mode", default: "off", null: false
    t.string "key", null: false
    t.string "kind", default: "disk", null: false
    t.string "label", null: false
    t.integer "position", default: 0, null: false
    t.bigint "quota_bytes"
    t.boolean "read_only", default: false, null: false
    t.string "root"
    t.string "scan_cursor"
    t.datetime "updated_at", null: false
    t.string "watch_path"
    t.index ["key"], name: "index_dam_storage_locations_on_key", unique: true
  end

  create_table "dam_workflows", force: :cascade do |t|
    t.string "applies_to_media_types"
    t.datetime "created_at", null: false
    t.string "created_by_id"
    t.string "created_by_name"
    t.text "default_arguments"
    t.text "description"
    t.boolean "enabled", default: true, null: false
    t.string "entrypoint"
    t.datetime "last_run_at"
    t.string "name", null: false
    t.string "runtime", default: "ruby", null: false
    t.string "schedule"
    t.string "slug", null: false
    t.string "trigger", default: "manual", null: false
    t.datetime "updated_at", null: false
    t.index ["enabled"], name: "index_dam_workflows_on_enabled"
    t.index ["slug"], name: "index_dam_workflows_on_slug", unique: true
  end

  create_table "data_runner_group_run_items", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.string "current_step"
    t.string "dsl_name", null: false
    t.string "dsl_slug", null: false
    t.integer "duration_ms"
    t.text "error_message"
    t.bigint "group_run_id", null: false
    t.integer "position", null: false
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["group_run_id", "position"], name: "idx_group_run_items_position", unique: true
    t.index ["group_run_id"], name: "index_data_runner_group_run_items_on_group_run_id"
  end

  create_table "data_runner_group_runs", force: :cascade do |t|
    t.datetime "completed_at"
    t.integer "completed_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "current_dsl"
    t.integer "failed_count", default: 0, null: false
    t.string "group_name", null: false
    t.string "requested_by"
    t.string "run_id", null: false
    t.datetime "started_at"
    t.string "status", default: "queued", null: false
    t.integer "total_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["group_name", "status"], name: "index_data_runner_group_runs_on_group_name_and_status"
    t.index ["run_id"], name: "index_data_runner_group_runs_on_run_id", unique: true
  end

  create_table "development_runs", force: :cascade do |t|
    t.text "command_json", null: false
    t.datetime "created_at", null: false
    t.integer "exit_status"
    t.datetime "finished_at"
    t.text "output"
    t.string "requested_by", null: false
    t.string "script_key", null: false
    t.string "script_label", null: false
    t.datetime "started_at"
    t.string "status", default: "queued", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_development_runs_on_created_at"
    t.index ["status"], name: "index_development_runs_on_status"
  end

  create_table "employee_union_codes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "employee_id", null: false
    t.string "union_code", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_employee_union_codes_on_employee_id", unique: true
  end

  create_table "fleet_vehicle_garaging_form_locations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "fleet_vehicle_garaging_form_id", null: false
    t.string "location"
    t.datetime "updated_at", null: false
    t.index ["fleet_vehicle_garaging_form_id"], name: "idx_on_fleet_vehicle_garaging_form_id_410cf98ab8"
  end

  create_table "fleet_vehicle_garaging_forms", force: :cascade do |t|
    t.string "agency"
    t.string "approver_id"
    t.datetime "created_at", null: false
    t.text "deny_reason"
    t.string "department"
    t.string "division"
    t.string "do_you_have_a_secondary_location", limit: 3
    t.string "email"
    t.string "employee_id"
    t.bigint "fleet_vehicle_id"
    t.string "is_this_a_take_home_vehicle", limit: 3
    t.string "last_known_location", limit: 200
    t.string "location"
    t.string "make", limit: 50
    t.string "model", limit: 50
    t.string "name"
    t.string "other_location", limit: 200
    t.string "other_secondary_location", limit: 200
    t.string "phone"
    t.string "secondary_location", limit: 200
    t.string "status", default: "in_progress", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
    t.string "vehicle_number", limit: 20
    t.integer "year"
    t.index ["approver_id"], name: "index_fleet_vehicle_garaging_forms_on_approver_id"
    t.index ["employee_id"], name: "index_fleet_vehicle_garaging_forms_on_employee_id"
    t.index ["fleet_vehicle_id"], name: "index_fleet_vehicle_garaging_forms_on_fleet_vehicle_id"
    t.index ["vehicle_number"], name: "index_fleet_vehicle_garaging_forms_on_vehicle_number"
  end

  create_table "fleet_vehicles", force: :cascade do |t|
    t.string "agency"
    t.string "budget_unit", limit: 10
    t.string "color", limit: 20
    t.datetime "created_at", null: false
    t.bigint "fleet_vehicle_garaging_form_id"
    t.string "garaging_location", limit: 200
    t.string "last_updated_by"
    t.integer "last_updated_by_employee_id"
    t.string "license_plate", limit: 15
    t.string "make", limit: 50
    t.string "model", limit: 50
    t.string "secondary_garaging_location", limit: 200
    t.string "take_home", limit: 3
    t.datetime "updated_at", null: false
    t.string "vehicle_number", limit: 20
    t.integer "year"
    t.index ["fleet_vehicle_garaging_form_id"], name: "index_fleet_vehicles_on_fleet_vehicle_garaging_form_id"
    t.index ["vehicle_number"], name: "index_fleet_vehicles_on_vehicle_number", unique: true, where: "([vehicle_number] IS NOT NULL)"
  end

  create_table "form_fields", force: :cascade do |t|
    t.integer "conditional_answer_field_id"
    t.text "conditional_answer_mappings"
    t.integer "conditional_field_id"
    t.text "conditional_values"
    t.datetime "created_at", null: false
    t.string "field_name", null: false
    t.string "field_type", null: false
    t.bigint "form_template_id", null: false
    t.boolean "has_custom_view", default: false, null: false
    t.string "label"
    t.text "options"
    t.integer "page_number", null: false
    t.integer "position"
    t.string "read_only", default: "none"
    t.boolean "required", default: false
    t.integer "restricted_to_employee_id"
    t.integer "restricted_to_group_id"
    t.string "restricted_to_org_filter_level"
    t.string "restricted_to_type", default: "none"
    t.datetime "updated_at", null: false
    t.boolean "visible_to_filler", default: false, null: false
  end

  create_table "form_request_forms", force: :cascade do |t|
    t.string "agency"
    t.string "approver_id"
    t.datetime "created_at", null: false
    t.text "deny_reason"
    t.string "department"
    t.string "division"
    t.string "email"
    t.string "employee_id"
    t.string "name"
    t.string "phone"
    t.string "status", default: "in_progress", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
    t.index ["approver_id"], name: "index_form_request_forms_on_approver_id"
    t.index ["employee_id"], name: "index_form_request_forms_on_employee_id"
  end

  create_table "form_submission_copies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "delivered_via", null: false
    t.datetime "dismissed_at"
    t.integer "recipient_employee_id", null: false
    t.bigint "submission_id", null: false
    t.string "submission_type", null: false
    t.datetime "updated_at", null: false
    t.index ["recipient_employee_id"], name: "index_form_submission_copies_on_recipient_employee_id"
    t.index ["submission_type", "submission_id", "recipient_employee_id"], name: "index_form_submission_copies_unique_per_recipient", unique: true
    t.index ["submission_type", "submission_id"], name: "index_form_submission_copies_on_submission"
  end

  create_table "form_subscription_opt_outs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "employee_id", null: false
    t.bigint "form_subscription_id", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_form_subscription_opt_outs_on_employee_id"
    t.index ["form_subscription_id", "employee_id"], name: "index_form_subscription_opt_outs_on_member", unique: true
  end

  create_table "form_subscriptions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "delivery_mode", default: "immediate", null: false
    t.string "employee_id"
    t.string "form_type", null: false
    t.string "grantee_type", null: false
    t.integer "group_id"
    t.boolean "notify_comment_added", default: false, null: false
    t.boolean "notify_created", default: false, null: false
    t.boolean "notify_edited", default: false, null: false
    t.boolean "notify_status_changed", default: false, null: false
    t.boolean "required", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["delivery_mode"], name: "index_form_subscriptions_on_delivery_mode"
    t.index ["form_type", "grantee_type", "employee_id", "group_id"], name: "index_form_subscriptions_on_target", unique: true
  end

  create_table "form_template_copy_recipients", force: :cascade do |t|
    t.string "authorization_service_type"
    t.datetime "created_at", null: false
    t.integer "employee_id"
    t.bigint "form_template_id", null: false
    t.integer "group_id"
    t.integer "position", default: 0
    t.string "recipient_type", null: false
    t.string "trigger_event", default: "approval", null: false
    t.datetime "updated_at", null: false
    t.index ["form_template_id"], name: "index_form_template_copy_recipients_on_form_template_id"
  end

  create_table "form_template_email_steps", force: :cascade do |t|
    t.boolean "attach_media", default: false, null: false
    t.boolean "attach_pdf", default: false, null: false
    t.string "authorization_service_type"
    t.datetime "created_at", null: false
    t.string "custom_email"
    t.integer "employee_id"
    t.bigint "form_template_id", null: false
    t.integer "group_id"
    t.integer "position", default: 0
    t.string "recipient_field_name"
    t.string "recipient_type", null: false
    t.integer "routing_step_number"
    t.string "trigger_event", default: "submit", null: false
    t.datetime "updated_at", null: false
    t.index ["form_template_id"], name: "index_form_template_email_steps_on_form_template_id"
  end

  create_table "form_template_emails", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.bigint "form_template_id", null: false
    t.string "kind", null: false
    t.string "subject"
    t.datetime "updated_at", null: false
    t.index ["form_template_id", "kind"], name: "index_form_template_emails_on_form_template_id_and_kind", unique: true
  end

  create_table "form_template_routing_steps", force: :cascade do |t|
    t.string "approve_button_label"
    t.string "authorization_service_type"
    t.boolean "complete_on_edit", default: false, null: false
    t.string "completion_rule", default: "all", null: false
    t.string "condition_field_name"
    t.string "condition_operator"
    t.string "condition_value"
    t.datetime "created_at", null: false
    t.string "deny_button_label"
    t.string "deny_rule", default: "form", null: false
    t.string "display_name"
    t.integer "employee_id"
    t.bigint "form_template_id", null: false
    t.bigint "form_template_status_id"
    t.integer "group_id"
    t.text "inbox_buttons"
    t.string "org_filter_level"
    t.string "routing_type", null: false
    t.integer "step_number", null: false
    t.datetime "updated_at", null: false
  end

  create_table "form_template_statuses", force: :cascade do |t|
    t.boolean "auto_generated", default: false
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.bigint "form_template_id", null: false
    t.boolean "is_end", default: false
    t.boolean "is_initial", default: false
    t.string "key", null: false
    t.string "name", null: false
    t.integer "position", default: 0
    t.datetime "updated_at", null: false
  end

  create_table "form_template_step_routes", force: :cascade do |t|
    t.string "authorization_service_type"
    t.datetime "created_at", null: false
    t.integer "employee_id"
    t.bigint "form_template_routing_step_id", null: false
    t.integer "group_id"
    t.string "label"
    t.string "org_filter_level"
    t.integer "position", default: 0, null: false
    t.string "routing_type", null: false
    t.datetime "updated_at", null: false
    t.index ["form_template_routing_step_id"], name: "idx_on_form_template_routing_step_id_6d4edb9b74"
  end

  create_table "form_templates", force: :cascade do |t|
    t.string "agency_id", limit: 10
    t.integer "approval_employee_id"
    t.string "approval_routing_to"
    t.boolean "archived", default: false, null: false
    t.string "class_name", null: false
    t.datetime "created_at", null: false
    t.integer "created_by"
    t.string "department_id", limit: 20
    t.string "description", limit: 500
    t.string "division_id", limit: 20
    t.string "form_number", limit: 30
    t.string "form_type", limit: 50
    t.boolean "has_dashboard", default: false
    t.text "inbox_buttons"
    t.integer "metabase_dashboard_id"
    t.string "name", null: false
    t.integer "page_count", default: 2, null: false
    t.text "page_headers"
    t.boolean "records_table", default: false, null: false
    t.string "reference_prefix"
    t.boolean "skip_code_generation", default: false, null: false
    t.string "status_transition_mode", default: "automatic"
    t.string "submission_type", default: "database"
    t.text "tags"
    t.string "unit_id", limit: 20
    t.datetime "updated_at", null: false
    t.index ["agency_id"], name: "index_form_templates_on_agency_id"
    t.index ["archived"], name: "index_form_templates_on_archived"
    t.index ["form_type"], name: "index_form_templates_on_form_type"
    t.index ["reference_prefix"], name: "index_form_templates_on_reference_prefix", unique: true, where: "([reference_prefix] IS NOT NULL)"
  end

  create_table "form_visibility_grants", force: :cascade do |t|
    t.string "agency_id"
    t.string "applies_to", default: "both", null: false
    t.datetime "created_at", null: false
    t.string "department_id"
    t.string "division_id"
    t.integer "employee_id"
    t.string "form_type", null: false
    t.string "grantee_type", null: false
    t.integer "group_id"
    t.string "unit_id"
    t.datetime "updated_at", null: false
    t.index ["form_type"], name: "index_form_visibility_grants_on_form_type"
    t.index ["grantee_type", "group_id"], name: "index_form_visibility_grants_on_grantee_type_and_group_id"
  end

  create_table "gsa_authorization_form_forms", force: :cascade do |t|
    t.string "agency"
    t.string "approver_id"
    t.datetime "created_at", null: false
    t.text "deny_reason"
    t.string "department"
    t.string "division"
    t.string "email"
    t.string "employee_id"
    t.string "name"
    t.string "phone"
    t.string "status", default: "in_progress", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
    t.index ["approver_id"], name: "index_gsa_authorization_form_forms_on_approver_id"
    t.index ["employee_id"], name: "index_gsa_authorization_form_forms_on_employee_id"
  end

  create_table "gym_locker_forms", force: :cascade do |t|
    t.string "agency"
    t.datetime "created_at", null: false
    t.string "department"
    t.string "division"
    t.string "email"
    t.string "employee_id"
    t.string "name"
    t.string "phone"
    t.string "status", default: "in_progress", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
  end

  create_table "help_tickets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.string "employee_email"
    t.string "employee_id", null: false
    t.string "employee_name"
    t.string "status", default: "open", null: false
    t.string "subject", null: false
    t.datetime "updated_at", null: false
  end

  create_table "id_badge_request_forms", force: :cascade do |t|
    t.string "agency"
    t.string "approver_id"
    t.datetime "created_at", null: false
    t.text "deny_reason"
    t.string "department"
    t.string "division"
    t.string "email"
    t.string "employee_id"
    t.string "name"
    t.string "phone"
    t.string "status", default: "in_progress", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
    t.index ["approver_id"], name: "index_id_badge_request_forms_on_approver_id"
    t.index ["employee_id"], name: "index_id_badge_request_forms_on_employee_id"
  end

  create_table "injury_categories", force: :cascade do |t|
    t.text "description", null: false
  end

  create_table "injury_classification_views", id: false, force: :cascade do |t|
    t.text "injury_category_description", null: false
    t.bigint "injury_category_id", null: false
    t.text "injury_classification_description", null: false
    t.bigint "injury_classification_id", null: false
    t.integer "sort_order", null: false
  end

  create_table "injury_classifications", force: :cascade do |t|
    t.text "description", null: false
  end

  create_table "leave_of_absence_forms", force: :cascade do |t|
    t.string "agency"
    t.string "approver_id"
    t.datetime "created_at", null: false
    t.text "deny_reason"
    t.string "department"
    t.string "division"
    t.string "email"
    t.string "employee_id"
    t.string "name"
    t.string "phone"
    t.string "status", default: "in_progress", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
  end

  create_table "notice_of_change_forms", force: :cascade do |t|
    t.string "activity"
    t.string "agency"
    t.string "annual_cost"
    t.string "approver_id"
    t.string "change_or_service_requested"
    t.datetime "created_at", null: false
    t.text "deny_reason"
    t.string "department"
    t.text "description_of_new_service"
    t.string "division"
    t.string "email"
    t.string "employee_id"
    t.string "function"
    t.string "monthly_cost"
    t.string "name"
    t.string "new_location_or_address"
    t.string "object"
    t.string "old_location_or_address"
    t.string "phase"
    t.string "phone"
    t.string "program"
    t.string "status", default: "in_progress", null: false
    t.string "task"
    t.string "unit"
    t.datetime "updated_at", null: false
  end

  create_table "org_permissions", force: :cascade do |t|
    t.string "agency_id"
    t.datetime "created_at", null: false
    t.string "department_id"
    t.string "division_id"
    t.string "permission_key", null: false
    t.string "permission_type", null: false
    t.string "unit_id"
    t.datetime "updated_at", null: false
  end

  create_table "osha_300a_entries", force: :cascade do |t|
    t.integer "annual_average_employees", default: 0, null: false
    t.string "change_reason", limit: 100
    t.datetime "created_at", null: false
    t.bigint "osha_establishment_id", null: false
    t.text "submission_response"
    t.datetime "submitted_at"
    t.string "submitted_by_id"
    t.text "submitted_payload"
    t.bigint "total_hours_worked", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "year", null: false
    t.index ["osha_establishment_id", "year"], name: "index_osha_300a_entries_on_osha_establishment_id_and_year", unique: true
    t.index ["osha_establishment_id"], name: "index_osha_300a_entries_on_osha_establishment_id"
  end

  create_table "osha_establishments", force: :cascade do |t|
    t.string "city", limit: 100, null: false
    t.string "company_name", limit: 100
    t.datetime "created_at", null: false
    t.string "ein", limit: 9, null: false
    t.integer "establishment_type"
    t.string "industry_description", limit: 300
    t.integer "naics_code", null: false
    t.string "name", limit: 100, null: false
    t.integer "size", null: false
    t.string "state", limit: 2, null: false
    t.string "street_address", limit: 100, null: false
    t.datetime "updated_at", null: false
    t.string "zip", limit: 9, null: false
    t.index ["name"], name: "index_osha_establishments_on_name", unique: true
  end

  create_table "osha_reports", force: :cascade do |t|
    t.string "agency"
    t.string "approver_id"
    t.string "case_classification"
    t.string "case_number_from_the_log"
    t.string "case_type"
    t.string "city"
    t.datetime "created_at", null: false
    t.datetime "date_hired"
    t.datetime "date_of_birth"
    t.datetime "date_of_death"
    t.datetime "date_of_injury_or_illness"
    t.text "deny_reason"
    t.string "department"
    t.string "did_employee_die"
    t.string "division"
    t.string "email"
    t.string "employee_id"
    t.string "facility_city"
    t.string "facility_name"
    t.string "facility_state"
    t.string "facility_street_address"
    t.string "facility_zip"
    t.string "name"
    t.string "name_of_physician_or_other_health_care_professional"
    t.string "phone"
    t.datetime "reportable_breach_notified_at"
    t.datetime "reportable_due_at"
    t.integer "restricted_duty_days"
    t.bigint "safety_report_id"
    t.string "sex"
    t.string "state"
    t.string "status", default: "in_progress", null: false
    t.string "street"
    t.datetime "time_employee_began_work"
    t.datetime "time_of_event"
    t.string "unit"
    t.datetime "updated_at", null: false
    t.string "was_the_employee_hospitalized_overnight_as_an_inpatient"
    t.string "was_the_employee_treated_in_an_emergency_room"
    t.string "was_treatment_given_away_from_the_worksite"
    t.text "what_happened_tell_us_how_the_injury_occurred"
    t.text "what_object_or_substance_directly_harmed_the_employee"
    t.text "what_was_the_employee_doing_just_before_the_incident_occurred"
    t.text "what_was_the_injury_or_illness"
    t.string "zip"
    t.index ["reportable_due_at", "reportable_breach_notified_at"], name: "index_osha_reports_on_reportable_deadline"
  end

  create_table "parking_lot_submissions", force: :cascade do |t|
    t.string "agency", limit: 100
    t.datetime "approved_at"
    t.string "approved_by", limit: 20
    t.string "approver_id"
    t.datetime "created_at", null: false
    t.text "denial_reason"
    t.datetime "denied_at"
    t.string "denied_by", limit: 20
    t.string "department", limit: 100
    t.string "division", limit: 100
    t.string "email", limit: 200
    t.string "employee_id", limit: 20
    t.string "name", limit: 200
    t.string "phone", limit: 25
    t.string "status", default: "in_progress", null: false
    t.string "supervisor_email", limit: 200
    t.string "supervisor_id", limit: 20
    t.string "unit", limit: 100
    t.datetime "updated_at", null: false
  end

  create_table "parking_lot_vehicles", force: :cascade do |t|
    t.text "carpool_participants"
    t.string "color", limit: 20
    t.datetime "created_at", null: false
    t.string "license_plate", limit: 15
    t.string "make", limit: 50
    t.string "model", limit: 50
    t.string "other_parking_lot", limit: 100
    t.string "other_permit_type", limit: 200
    t.string "parking_lot", limit: 100
    t.bigint "parking_lot_submission_id", null: false
    t.text "permit_type"
    t.datetime "updated_at", null: false
    t.integer "year"
  end

  create_table "pcard_inventories", force: :cascade do |t|
    t.string "address"
    t.string "agency"
    t.string "agent"
    t.string "approver_name"
    t.string "billing_contact"
    t.date "canceled_date"
    t.string "card_last_four", limit: 4
    t.string "card_number"
    t.string "city"
    t.string "company"
    t.datetime "created_at", null: false
    t.string "dept_head_agency"
    t.string "division"
    t.string "division_number"
    t.date "expiration_date"
    t.string "first_name"
    t.date "issued_date"
    t.string "last_name"
    t.string "mail_stop"
    t.decimal "monthly_limit", precision: 10, scale: 2
    t.string "org_number"
    t.bigint "pcard_request_form_id"
    t.string "phone"
    t.decimal "single_purchase_limit", precision: 10, scale: 2
    t.string "state"
    t.datetime "updated_at", null: false
    t.string "zip"
  end

  create_table "pcard_request_forms", force: :cascade do |t|
    t.string "agency"
    t.string "approver_id"
    t.datetime "created_at", null: false
    t.text "deny_reason"
    t.string "department"
    t.string "division"
    t.string "email"
    t.string "employee_id"
    t.string "name"
    t.string "phone"
    t.string "status", default: "in_progress", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
  end

  create_table "probation_transfer_requests", force: :cascade do |t|
    t.string "agency", limit: 100
    t.datetime "approved_at"
    t.string "approved_by", limit: 20
    t.string "approved_destination"
    t.datetime "canceled_at"
    t.string "canceled_reason", limit: 100
    t.datetime "created_at", null: false
    t.date "current_assignment_date"
    t.text "denial_reason"
    t.datetime "denied_at"
    t.string "denied_by", limit: 20
    t.string "department", limit: 100
    t.text "desired_transfer_destination"
    t.string "division", limit: 100
    t.string "email", limit: 200
    t.string "employee_id", limit: 20
    t.datetime "expires_at"
    t.string "name", limit: 200
    t.string "other_transfer_destination", limit: 200
    t.string "phone", limit: 25
    t.string "status", default: "in_progress", null: false
    t.bigint "superseded_by_id"
    t.string "supervisor_email", limit: 200
    t.string "supervisor_id", limit: 20
    t.string "unit", limit: 100
    t.datetime "updated_at", null: false
    t.string "work_location", limit: 100
  end

  create_table "record_edits", force: :cascade do |t|
    t.string "action", limit: 10, default: "update", null: false
    t.string "changed_by_id"
    t.string "changed_by_name"
    t.string "column_name", null: false
    t.datetime "created_at", null: false
    t.text "new_value"
    t.text "old_value"
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.string "table_slug", null: false
    t.index ["created_at"], name: "index_record_edits_on_created_at"
    t.index ["record_type", "created_at"], name: "index_record_edits_on_record_type_and_created_at"
    t.index ["record_type", "record_id"], name: "index_record_edits_on_record_type_and_record_id"
  end

  create_table "records_email_contacts", force: :cascade do |t|
    t.string "column_name", limit: 100, null: false
    t.datetime "created_at", null: false
    t.integer "created_by_employee_id"
    t.string "email", limit: 255, null: false
    t.string "match_value", limit: 200, null: false
    t.string "table_slug", limit: 100, null: false
    t.datetime "updated_at", null: false
    t.index ["table_slug", "column_name", "match_value", "email"], name: "index_records_email_contacts_unique", unique: true
  end

  create_table "records_email_deliveries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "group_value"
    t.text "recipients"
    t.bigint "records_email_rule_id"
    t.integer "row_count", default: 0, null: false
    t.string "sent_by_employee_id"
    t.string "subject"
    t.string "table_slug", limit: 100, null: false
    t.index ["records_email_rule_id"], name: "index_records_email_deliveries_on_records_email_rule_id"
    t.index ["table_slug", "created_at"], name: "index_records_email_deliveries_on_table_slug_and_created_at"
  end

  create_table "records_email_rules", force: :cascade do |t|
    t.string "column_name", null: false
    t.datetime "created_at", null: false
    t.integer "day_of_month"
    t.integer "day_of_week"
    t.string "employee_id", null: false
    t.boolean "enabled", default: true, null: false
    t.string "frequency", null: false
    t.string "label", null: false
    t.datetime "last_run_at"
    t.text "message", null: false
    t.datetime "next_run_at"
    t.string "operator", null: false
    t.text "recipients"
    t.string "split_column"
    t.string "table_slug", limit: 100, null: false
    t.string "time_of_day", null: false
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["enabled", "next_run_at"], name: "index_records_email_rules_on_enabled_and_next_run_at"
    t.index ["table_slug"], name: "index_records_email_rules_on_table_slug"
  end

  create_table "records_highlight_rules", force: :cascade do |t|
    t.string "color", null: false
    t.string "column_name", null: false
    t.datetime "created_at", null: false
    t.integer "created_by_employee_id"
    t.string "label"
    t.string "operator", null: false
    t.integer "position", default: 0, null: false
    t.string "table_slug", null: false
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["table_slug", "position"], name: "index_records_highlight_rules_on_table_slug_and_position"
  end

  create_table "safety_report_authorizations", force: :cascade do |t|
    t.string "authorized_by"
    t.datetime "created_at", null: false
    t.string "division_id", null: false
    t.string "employee_id", null: false
    t.datetime "updated_at", null: false
    t.index ["division_id"], name: "index_safety_report_authorizations_on_division_id"
    t.index ["employee_id", "division_id"], name: "index_safety_report_authorizations_on_employee_and_division", unique: true
  end

  create_table "safety_reports", force: :cascade do |t|
    t.text "activity_at_time_of_incident"
    t.datetime "actual_completion_date"
    t.string "agency"
    t.string "approver_id"
    t.text "assessment_of_future_severity_potential"
    t.text "assessment_of_probability_of_recurrence"
    t.string "bloodborne_pathogen_exposure"
    t.text "cause_of_incident"
    t.string "checklistprocedurestraining_modified"
    t.string "corrective_department"
    t.string "corrective_phone"
    t.datetime "created_at", null: false
    t.datetime "date_dwc1_given"
    t.datetime "date_employer_notified"
    t.datetime "date_last_worked"
    t.datetime "date_of_injury_or_illness"
    t.datetime "date_returned_to_work"
    t.text "deny_reason"
    t.string "department"
    t.string "department_where_event_occurred"
    t.string "division"
    t.string "email"
    t.string "employee_id"
    t.string "employee_medical_number"
    t.string "hospital_address"
    t.string "hospital_name"
    t.string "hospital_phone"
    t.string "hospitalized_overnight"
    t.text "how_the_injury_occurred"
    t.text "impacted_employee"
    t.string "impacted_employees_email"
    t.string "impacted_employees_phone"
    t.string "impacted_employees_supervisor"
    t.string "investigator_name"
    t.string "investigator_phone"
    t.string "investigator_title"
    t.string "is_the_employees_blood_tested"
    t.string "is_the_source_blood_tested"
    t.text "location_description"
    t.string "location_of_incident"
    t.string "medical_record_number_for_the_employee"
    t.string "missed_full_work_day_"
    t.string "name"
    t.text "nature_of_incident"
    t.string "on_employer_premises"
    t.string "osha_recordable"
    t.string "osha_reportable"
    t.string "other_hospital"
    t.string "other_hospital_address"
    t.string "other_hospital_phone"
    t.string "person_responsible_for_corrective_action"
    t.string "phone"
    t.string "physician_address"
    t.string "physician_name"
    t.string "physician_phone"
    t.string "report_type"
    t.string "reportable_injury_codes"
    t.text "root_cause"
    t.string "source_patient_medical_number"
    t.text "specific_injury_and_body_part_affected"
    t.string "status", default: "in_progress", null: false
    t.string "still_off_work"
    t.string "supervisor_name"
    t.datetime "targeted_completion_date"
    t.string "title"
    t.string "unit"
    t.string "unsafe_condition_corrected_immediately"
    t.datetime "updated_at", null: false
    t.string "who_gave_the_dwc1"
    t.string "witness_name"
    t.string "witness_phone"
  end

  create_table "saved_searches", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "employee_id", null: false
    t.text "filters", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "scheduled_record_exports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "day_of_month"
    t.integer "day_of_week"
    t.string "employee_id", null: false
    t.boolean "enabled", default: true, null: false
    t.string "frequency", null: false
    t.datetime "last_run_at"
    t.text "layout"
    t.datetime "next_run_at"
    t.string "table_slug", limit: 100, null: false
    t.string "time_of_day", null: false
    t.datetime "updated_at", null: false
    t.text "view_params"
    t.index ["employee_id", "table_slug"], name: "index_scheduled_record_exports_on_employee_id_and_table_slug"
    t.index ["enabled", "next_run_at"], name: "index_scheduled_record_exports_on_enabled_and_next_run_at"
  end

  create_table "scheduled_reports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "date_range_type", null: false
    t.integer "day_of_month"
    t.integer "day_of_week"
    t.string "employee_id", null: false
    t.boolean "enabled", default: true, null: false
    t.string "form_type", null: false
    t.string "format", default: "csv", null: false
    t.string "frequency", null: false
    t.datetime "last_run_at"
    t.datetime "next_run_at"
    t.string "status_filter"
    t.string "time_of_day", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sheriff_safety_reporting_forms", force: :cascade do |t|
    t.text "activity_at_time_of_incident"
    t.datetime "actual_completion_date"
    t.string "agency"
    t.string "approver_id"
    t.text "assessment_of_future_severity_potential"
    t.text "assessment_of_probability_of_recurrence"
    t.string "bloodborne_pathogen_exposure"
    t.text "cause_of_incident"
    t.string "checklistprocedurestraining_modified"
    t.string "corrective_department"
    t.string "corrective_phone"
    t.datetime "created_at", null: false
    t.datetime "date_dwc1_given"
    t.datetime "date_employer_notified"
    t.datetime "date_last_worked"
    t.datetime "date_of_injury_or_illness"
    t.datetime "date_returned_to_work"
    t.text "deny_reason"
    t.string "department"
    t.string "department_where_event_occurred"
    t.string "division"
    t.string "email"
    t.string "employee_id"
    t.string "employee_medical_number"
    t.string "hospital_address"
    t.string "hospital_name"
    t.string "hospital_phone"
    t.string "hospitalized_overnight"
    t.text "how_the_injury_occurred"
    t.text "impacted_employee"
    t.string "impacted_employees_email"
    t.string "impacted_employees_phone"
    t.string "impacted_employees_supervisor"
    t.string "investigator_name"
    t.string "investigator_phone"
    t.string "investigator_title"
    t.string "is_the_employees_blood_tested"
    t.string "is_the_source_blood_tested"
    t.text "location_description"
    t.string "location_of_incident"
    t.string "medical_record_number_for_the_employee"
    t.string "missed_full_work_day_"
    t.string "name"
    t.text "nature_of_incident"
    t.string "on_employer_premises"
    t.string "osha_recordable"
    t.string "osha_reportable"
    t.string "other_hospital"
    t.string "other_hospital_address"
    t.string "other_hospital_phone"
    t.string "person_responsible_for_corrective_action"
    t.string "phone"
    t.string "physician_address"
    t.string "physician_name"
    t.string "physician_phone"
    t.string "report_type"
    t.string "reportable_injury_codes"
    t.text "root_cause"
    t.string "source_patient_medical_number"
    t.text "specific_injury_and_body_part_affected"
    t.string "status", default: "in_progress", null: false
    t.string "still_off_work"
    t.string "supervisor_name"
    t.datetime "targeted_completion_date"
    t.string "title"
    t.string "unit"
    t.string "unsafe_condition_corrected_immediately"
    t.datetime "updated_at", null: false
    t.string "who_gave_the_dwc1"
    t.string "witness_name"
    t.string "witness_phone"
  end

  create_table "social_media_forms", force: :cascade do |t|
    t.string "agency"
    t.datetime "created_at", null: false
    t.string "department"
    t.string "division"
    t.string "email"
    t.string "employee_id"
    t.string "name"
    t.string "phone"
    t.string "status", default: "in_progress", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", null: false
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", null: false
    t.bigint "key_hash", null: false
    t.binary "value", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_batch_executions", force: :cascade do |t|
    t.bigint "batch_id", null: false
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.index ["batch_id"], name: "index_solid_queue_batch_executions_on_batch_id"
    t.index ["job_id"], name: "index_solid_queue_batch_executions_on_job_id", unique: true
  end

  create_table "solid_queue_batches", force: :cascade do |t|
    t.string "active_job_batch_id"
    t.integer "completed_jobs", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.datetime "enqueued_at"
    t.datetime "failed_at"
    t.integer "failed_jobs", default: 0, null: false
    t.datetime "finished_at"
    t.text "metadata"
    t.text "on_failure"
    t.text "on_finish"
    t.text "on_success"
    t.integer "total_jobs", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_batch_id"], name: "index_solid_queue_batches_on_active_job_batch_id", unique: true
    t.index ["finished_at"], name: "index_solid_queue_batches_on_finished_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.bigint "batch_id"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["batch_id"], name: "index_solid_queue_jobs_on_batch_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "status_changes", force: :cascade do |t|
    t.string "changed_by_id"
    t.string "changed_by_name"
    t.datetime "created_at", null: false
    t.string "from_status"
    t.text "notes"
    t.string "to_status", null: false
    t.bigint "trackable_id", null: false
    t.string "trackable_type", null: false
    t.datetime "updated_at", null: false
  end

  create_table "submission_comments", force: :cascade do |t|
    t.string "author_id"
    t.string "author_name"
    t.text "body"
    t.bigint "commentable_id", null: false
    t.string "commentable_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["commentable_type", "commentable_id", "created_at"], name: "index_submission_comments_on_commentable"
    t.index ["commentable_type", "created_at"], name: "index_submission_comments_on_commentable_type_and_created_at"
  end

  create_table "submission_step_tasks", force: :cascade do |t|
    t.datetime "acted_at"
    t.string "acted_by_id"
    t.string "acted_by_name"
    t.string "assignee_id"
    t.string "authorization_service_type"
    t.datetime "created_at", null: false
    t.integer "employee_id"
    t.integer "group_id"
    t.string "label", null: false
    t.text "notes"
    t.string "org_filter_level"
    t.integer "position", default: 0, null: false
    t.string "routing_type", null: false
    t.string "state", default: "pending", null: false
    t.integer "step_number", null: false
    t.bigint "submission_id", null: false
    t.string "submission_type", null: false
    t.datetime "updated_at", null: false
    t.index ["submission_type", "state", "assignee_id"], name: "index_submission_step_tasks_on_open_assignee"
    t.index ["submission_type", "submission_id", "step_number"], name: "index_submission_step_tasks_on_submission"
  end

  create_table "task_reassignments", force: :cascade do |t|
    t.string "assignment_field"
    t.datetime "created_at", null: false
    t.string "from_employee_id", null: false
    t.text "reason"
    t.string "reassigned_by_id", null: false
    t.bigint "task_id", null: false
    t.string "task_type", null: false
    t.string "to_employee_id", null: false
    t.datetime "updated_at", null: false
  end

  create_table "telework_log_form_hours", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "hours"
    t.bigint "telework_log_form_id", null: false
    t.datetime "updated_at", null: false
    t.index ["telework_log_form_id"], name: "index_telework_log_form_hours_on_telework_log_form_id"
  end

  create_table "telework_log_form_work_performeds", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "hours"
    t.bigint "telework_log_form_id", null: false
    t.datetime "updated_at", null: false
    t.text "work_performed"
    t.index ["telework_log_form_id"], name: "idx_on_telework_log_form_id_793165cd13"
  end

  create_table "telework_log_forms", force: :cascade do |t|
    t.string "agency"
    t.string "approver_id"
    t.datetime "created_at", null: false
    t.text "deny_reason"
    t.string "department"
    t.string "division"
    t.string "email"
    t.string "employee_id"
    t.string "name"
    t.string "phone"
    t.string "status", default: "in_progress", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
    t.index ["approver_id"], name: "index_telework_log_forms_on_approver_id"
    t.index ["employee_id"], name: "index_telework_log_forms_on_employee_id"
  end

  create_table "textbook_and_tuition_reimbursement_forms", force: :cascade do |t|
    t.string "agency"
    t.string "approver_id"
    t.datetime "created_at", null: false
    t.text "deny_reason"
    t.string "department"
    t.string "division"
    t.string "email"
    t.string "employee_id"
    t.string "name"
    t.string "phone"
    t.string "status", default: "in_progress", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
    t.index ["approver_id"], name: "index_textbook_and_tuition_reimbursement_forms_on_approver_id"
    t.index ["employee_id"], name: "index_textbook_and_tuition_reimbursement_forms_on_employee_id"
  end

  create_table "user_settings", force: :cascade do |t|
    t.text "column_prefs"
    t.datetime "created_at", null: false
    t.integer "dam_storage_location_id"
    t.string "employee_id", null: false
    t.boolean "inbox_email_notifications", default: false, null: false
    t.string "theme", default: "light", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_user_settings_on_employee_id", unique: true
  end

  create_table "work_schedule_or_location_update_forms", force: :cascade do |t|
    t.string "agency"
    t.string "approver_id"
    t.datetime "created_at", null: false
    t.text "deny_reason"
    t.string "department"
    t.string "division"
    t.string "email"
    t.string "employee_id"
    t.string "name"
    t.string "phone"
    t.string "status", default: "in_progress", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
  end

  create_table "workplace_violence_forms", force: :cascade do |t|
    t.string "agency"
    t.string "approver_id"
    t.datetime "created_at", null: false
    t.text "deny_reason"
    t.string "department"
    t.string "division"
    t.string "email"
    t.string "employee_id"
    t.string "name"
    t.string "phone"
    t.string "status", default: "in_progress", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "dam_assets", "dam_storage_locations", column: "storage_location_id"
  add_foreign_key "dam_collection_assets", "dam_assets", column: "asset_id"
  add_foreign_key "dam_collection_assets", "dam_collections", column: "collection_id"
  add_foreign_key "dam_collections", "dam_collections", column: "parent_id"
  add_foreign_key "dam_ingest_failures", "dam_storage_locations", column: "storage_location_id"
  add_foreign_key "dam_jobs", "dam_workflows", column: "workflow_id"
  add_foreign_key "dam_metadata_values", "dam_assets", column: "asset_id"
  add_foreign_key "dam_publications", "dam_assets", column: "asset_id"
  add_foreign_key "dam_publications", "dam_publish_targets", column: "publish_target_id"
  add_foreign_key "data_runner_group_run_items", "data_runner_group_runs", column: "group_run_id"
  add_foreign_key "fleet_vehicle_garaging_forms", "fleet_vehicles"
  add_foreign_key "form_fields", "form_templates"
  add_foreign_key "form_subscription_opt_outs", "form_subscriptions", on_delete: :cascade
  add_foreign_key "form_template_copy_recipients", "form_templates"
  add_foreign_key "form_template_email_steps", "form_templates"
  add_foreign_key "form_template_emails", "form_templates"
  add_foreign_key "form_template_routing_steps", "form_template_statuses"
  add_foreign_key "form_template_routing_steps", "form_templates"
  add_foreign_key "form_template_statuses", "form_templates"
  add_foreign_key "osha_300a_entries", "osha_establishments"
  add_foreign_key "parking_lot_vehicles", "parking_lot_submissions"
  add_foreign_key "pcard_inventories", "pcard_request_forms"
  add_foreign_key "solid_queue_batch_executions", "solid_queue_batches", column: "batch_id", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id"
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id"
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id"
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id"
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id"
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id"
end
