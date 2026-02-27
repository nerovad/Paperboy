namespace :db do
  desc "Migrate data from MSSQL (GSABSS) to PostgreSQL"
  task migrate_from_mssql: :environment do
    puts "=== Starting MSSQL → PostgreSQL Data Migration ==="
    puts ""

    mssql = BillingBase.connection

    # ---------------------------------------------------------------
    # 1. Employees
    # ---------------------------------------------------------------
    puts "Migrating Employees..."
    rows = mssql.exec_query("SELECT * FROM GSABSS.dbo.Employees")
    rows.each do |row|
      Employee.upsert({
        employee_id:          row["EmployeeID"],
        first_name:           row["First_Name"],
        last_name:            row["Last_Name"],
        email:                row["EE_Email"],
        work_phone:           row["Work_Phone"],
        supervisor_id:        row["Supervisor_ID"],
        supervisor_first_name: row["Supervisor_First_Name"],
        supervisor_last_name: row["Supervisor_Last_Name"],
        job_title:            row["Job_Title"],
        job_code:             row["Job_Code"],
        job_class:            row["Job_Class"],
        pay_status:           row["Pay_Status"],
        union_code:           row["Union_Code"],
        employee_type:        row["Type"],
        agency:               row["Agency"],
        department:           row["Department"],
        unit:                 row["Unit"],
        position:             row["Position"]
      }, unique_by: :employee_id)
    end
    puts "  → #{Employee.count} employees"

    # ---------------------------------------------------------------
    # 2. Groups (new auto-increment IDs)
    # ---------------------------------------------------------------
    puts "Migrating Groups..."
    group_id_map = {} # old GroupID → new id

    old_groups = mssql.exec_query("SELECT * FROM GSABSS.dbo.Groups ORDER BY GroupID")
    old_groups.each do |row|
      group = Group.create!(
        group_name:  row["Group_Name"],
        description: row["Description"],
        created_at:  row["Created_At"] || Time.current
      )
      group_id_map[row["GroupID"]] = group.id
    end
    puts "  → #{Group.count} groups (ID map: #{group_id_map.size} entries)"

    # ---------------------------------------------------------------
    # 3. Employee Groups (remap group_id)
    # ---------------------------------------------------------------
    puts "Migrating Employee Groups..."
    old_egs = mssql.exec_query("SELECT * FROM GSABSS.dbo.Employee_Groups")
    old_egs.each do |row|
      new_group_id = group_id_map[row["GroupID"]]
      next unless new_group_id

      EmployeeGroup.find_or_create_by!(
        employee_id: row["EmployeeID"],
        group_id:    new_group_id
      ) do |eg|
        eg.assigned_at = row["Assigned_At"]
        eg.assigned_by = row["Assigned_By"]
      end
    end
    puts "  → #{EmployeeGroup.count} employee-group assignments"

    # ---------------------------------------------------------------
    # 4. Group Permissions (remap group_id)
    # ---------------------------------------------------------------
    puts "Migrating Group Permissions..."
    old_perms = mssql.exec_query("SELECT * FROM GSABSS.dbo.Group_Permissions")
    old_perms.each do |row|
      new_group_id = group_id_map[row["GroupID"]]
      next unless new_group_id

      GroupPermission.find_or_create_by!(
        group_id:        new_group_id,
        permission_type: row["Permission_Type"],
        permission_key:  row["Permission_Key"]
      )
    end
    puts "  → #{GroupPermission.count} group permissions"

    # ---------------------------------------------------------------
    # 5. Org Hierarchy Tables (already snake_case, direct copy)
    # ---------------------------------------------------------------
    migrate_org_table(mssql, "agencies",        Agency,        "agency_id")
    migrate_org_table(mssql, "divisions",       Division,      "agency_id, division_id")
    migrate_org_table(mssql, "departments",     Department,    "agency_id, division_id, department_id")
    migrate_org_table(mssql, "units",           Unit,          "agency_id, division_id, department_id, unit_id")
    migrate_org_table(mssql, "activities",      nil,           nil, table: "activities")
    migrate_org_table(mssql, "functions",       nil,           nil, table: "functions")
    migrate_org_table(mssql, "funds",           nil,           nil, table: "funds")
    migrate_org_table(mssql, "department_funds", nil,          nil, table: "department_funds")
    migrate_org_table(mssql, "major_programs",  nil,           nil, table: "major_programs")
    migrate_org_table(mssql, "programs",        nil,           nil, table: "programs")
    migrate_org_table(mssql, "phases",          nil,           nil, table: "phases")
    migrate_org_table(mssql, "tasks",           nil,           nil, table: "tasks")
    migrate_org_table(mssql, "revenue_sources", nil,           nil, table: "revenue_sources")
    migrate_org_table(mssql, "objects",         nil,           nil, table: "objects")
    migrate_org_table(mssql, "sub_objects",     nil,           nil, table: "sub_objects")
    migrate_org_table(mssql, "sub_units",       nil,           nil, table: "sub_units")

    # ---------------------------------------------------------------
    # 6. App data tables (direct copy)
    # ---------------------------------------------------------------
    app_tables = %w[
      form_templates form_fields form_template_statuses form_template_routing_steps
      status_changes saved_searches scheduled_reports help_tickets
      authorization_managers authorized_approvers task_reassignments
      parking_lot_submissions parking_lot_vehicles probation_transfer_requests
      critical_information_reportings creative_job_requests
      carpool_forms gym_locker_forms social_media_forms brown_mail_forms
      osha301_forms rm75_forms leave_of_absence_forms
      work_schedule_or_location_update_forms workplace_violence_forms
      notice_of_change_forms testyyy_forms authorization_fos
    ]
    app_tables.each do |t|
      migrate_org_table(mssql, t, nil, nil, table: t)
    end

    # ---------------------------------------------------------------
    # 7. Remap acl_group_id in form_templates
    # ---------------------------------------------------------------
    puts "Remapping form_templates.acl_group_id..."
    FormTemplate.where.not(acl_group_id: nil).find_each do |ft|
      new_id = group_id_map[ft.acl_group_id]
      ft.update_column(:acl_group_id, new_id) if new_id
    end

    # ---------------------------------------------------------------
    # 8. Remap restricted_to_group_id in form_fields
    # ---------------------------------------------------------------
    puts "Remapping form_fields.restricted_to_group_id..."
    FormField.where(restricted_to_type: "group").where.not(restricted_to_group_id: nil).find_each do |ff|
      new_id = group_id_map[ff.restricted_to_group_id]
      ff.update_column(:restricted_to_group_id, new_id) if new_id
    end

    puts ""
    puts "=== Migration Complete ==="
    puts "  Employees:        #{Employee.count}"
    puts "  Groups:           #{Group.count}"
    puts "  Employee Groups:  #{EmployeeGroup.count}"
    puts "  Group Permissions: #{GroupPermission.count}"
  end
end

def migrate_org_table(mssql, source_table, model_class = nil, _pk = nil, table: nil)
  dest_table = table || source_table
  print "Migrating #{source_table}..."

  begin
    rows = mssql.exec_query("SELECT * FROM GSABSS.dbo.#{source_table}")
  rescue => e
    puts " SKIPPED (#{e.message.truncate(80)})"
    return
  end

  return puts(" 0 rows") if rows.empty?

  conn = ActiveRecord::Base.connection
  cols = rows.columns.map { |c| conn.quote_column_name(c) }.join(", ")

  rows.each do |row|
    values = row.values.map { |v| conn.quote(v) }.join(", ")
    conn.execute("INSERT INTO #{dest_table} (#{cols}) VALUES (#{values}) ON CONFLICT DO NOTHING")
  end

  count = conn.exec_query("SELECT COUNT(*) AS cnt FROM #{dest_table}").first["cnt"]
  puts " #{count} rows"
end
