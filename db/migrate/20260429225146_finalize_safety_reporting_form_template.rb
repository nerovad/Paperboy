class FinalizeSafetyReportingFormTemplate < ActiveRecord::Migration[8.0]
  def up
    template = ActiveRecord::Base.connection.select_one(
      "SELECT id FROM form_templates WHERE class_name = 'SafetyReport'"
    )
    return unless template

    execute "UPDATE form_templates SET name = 'Safety Reporting' WHERE class_name = 'SafetyReport'"

    template_id = template["id"].to_s

    execute <<~SQL
      UPDATE Group_Permissions
      SET Permission_Key = '#{template_id}'
      WHERE Permission_Type = 'form' AND Permission_Key = 'safety_reporting'
    SQL

    if ActiveRecord::Base.connection.table_exists?(:org_permissions)
      execute <<~SQL
        UPDATE org_permissions
        SET permission_key = '#{template_id}'
        WHERE permission_type = 'form' AND permission_key = 'safety_reporting'
      SQL
    end
  end

  def down
    template = ActiveRecord::Base.connection.select_one(
      "SELECT id FROM form_templates WHERE class_name = 'SafetyReport'"
    )
    return unless template

    template_id = template["id"].to_s

    execute <<~SQL
      UPDATE Group_Permissions
      SET Permission_Key = 'safety_reporting'
      WHERE Permission_Type = 'form' AND Permission_Key = '#{template_id}'
    SQL

    if ActiveRecord::Base.connection.table_exists?(:org_permissions)
      execute <<~SQL
        UPDATE org_permissions
        SET permission_key = 'safety_reporting'
        WHERE permission_type = 'form' AND permission_key = '#{template_id}'
      SQL
    end

    execute "UPDATE form_templates SET name = 'RM75' WHERE class_name = 'SafetyReport'"
  end
end
