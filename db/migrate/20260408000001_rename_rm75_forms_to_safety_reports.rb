class RenameRm75FormsToSafetyReports < ActiveRecord::Migration[8.0]
  def up
    rename_table :rm75_forms, :safety_reports
    rename_column :osha301_forms, :rm75_form_id, :safety_report_id

    # Update ACL permission keys: 'rm75' -> 'safety_reporting'
    execute <<~SQL
      UPDATE Group_Permissions
      SET Permission_Key = 'safety_reporting'
      WHERE Permission_Type = 'form' AND Permission_Key = 'rm75'
    SQL

    if ActiveRecord::Base.connection.table_exists?(:org_permissions)
      execute <<~SQL
        UPDATE org_permissions
        SET permission_key = 'safety_reporting'
        WHERE permission_type = 'form' AND permission_key = 'rm75'
      SQL
    end

    # Update FormTemplate class_name reference if one exists
    if ActiveRecord::Base.connection.table_exists?(:form_templates)
      execute <<~SQL
        UPDATE form_templates
        SET class_name = 'SafetyReport'
        WHERE class_name = 'Rm75Form'
      SQL
    end
  end

  def down
    if ActiveRecord::Base.connection.table_exists?(:form_templates)
      execute <<~SQL
        UPDATE form_templates
        SET class_name = 'Rm75Form'
        WHERE class_name = 'SafetyReport'
      SQL
    end

    if ActiveRecord::Base.connection.table_exists?(:org_permissions)
      execute <<~SQL
        UPDATE org_permissions
        SET permission_key = 'rm75'
        WHERE permission_type = 'form' AND permission_key = 'safety_reporting'
      SQL
    end

    execute <<~SQL
      UPDATE Group_Permissions
      SET Permission_Key = 'rm75'
      WHERE Permission_Type = 'form' AND Permission_Key = 'safety_reporting'
    SQL

    rename_column :osha301_forms, :safety_report_id, :rm75_form_id
    rename_table :safety_reports, :rm75_forms
  end
end
