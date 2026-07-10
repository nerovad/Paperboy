class FinalizeOshaReportingFormTemplate < ActiveRecord::Migration[8.0]
  def up
    template = ActiveRecord::Base.connection.select_one(
      "SELECT id FROM form_templates WHERE class_name = 'OshaReport'"
    )
    return unless template

    execute "UPDATE form_templates SET name = 'OSHA Reporting' WHERE class_name = 'OshaReport'"

    template_id = template['id'].to_s

    execute <<~SQL
      UPDATE Group_Permissions
      SET Permission_Key = '#{template_id}'
      WHERE Permission_Type = 'form' AND Permission_Key = 'osha_reporting'
    SQL

    return unless ActiveRecord::Base.connection.table_exists?(:org_permissions)

    execute <<~SQL
      UPDATE org_permissions
      SET permission_key = '#{template_id}'
      WHERE permission_type = 'form' AND permission_key = 'osha_reporting'
    SQL
  end

  def down
    template = ActiveRecord::Base.connection.select_one(
      "SELECT id FROM form_templates WHERE class_name = 'OshaReport'"
    )
    return unless template

    template_id = template['id'].to_s

    execute <<~SQL
      UPDATE Group_Permissions
      SET Permission_Key = 'osha_reporting'
      WHERE Permission_Type = 'form' AND Permission_Key = '#{template_id}'
    SQL

    if ActiveRecord::Base.connection.table_exists?(:org_permissions)
      execute <<~SQL
        UPDATE org_permissions
        SET permission_key = 'osha_reporting'
        WHERE permission_type = 'form' AND permission_key = '#{template_id}'
      SQL
    end

    execute "UPDATE form_templates SET name = 'OSHA 301' WHERE class_name = 'OshaReport'"
  end
end
