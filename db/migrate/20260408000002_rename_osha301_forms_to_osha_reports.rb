class RenameOsha301FormsToOshaReports < ActiveRecord::Migration[8.0]
  def up
    rename_table :osha301_forms, :osha_reports

    # Update ACL permission keys: 'osha301' -> 'osha_reporting'
    execute <<~SQL
      UPDATE Group_Permissions
      SET Permission_Key = 'osha_reporting'
      WHERE Permission_Type = 'form' AND Permission_Key = 'osha301'
    SQL

    if ActiveRecord::Base.connection.table_exists?(:org_permissions)
      execute <<~SQL
        UPDATE org_permissions
        SET permission_key = 'osha_reporting'
        WHERE permission_type = 'form' AND permission_key = 'osha301'
      SQL
    end

    # Update FormTemplate class_name reference if one exists
    if ActiveRecord::Base.connection.table_exists?(:form_templates)
      execute <<~SQL
        UPDATE form_templates
        SET class_name = 'OshaReport'
        WHERE class_name = 'Osha301Form'
      SQL
    end
  end

  def down
    if ActiveRecord::Base.connection.table_exists?(:form_templates)
      execute <<~SQL
        UPDATE form_templates
        SET class_name = 'Osha301Form'
        WHERE class_name = 'OshaReport'
      SQL
    end

    if ActiveRecord::Base.connection.table_exists?(:org_permissions)
      execute <<~SQL
        UPDATE org_permissions
        SET permission_key = 'osha301'
        WHERE permission_type = 'form' AND permission_key = 'osha_reporting'
      SQL
    end

    execute <<~SQL
      UPDATE Group_Permissions
      SET Permission_Key = 'osha301'
      WHERE Permission_Type = 'form' AND Permission_Key = 'osha_reporting'
    SQL

    rename_table :osha_reports, :osha301_forms
  end
end
