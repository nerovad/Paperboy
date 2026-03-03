class RevertMetabaseToPowerbi < ActiveRecord::Migration[8.0]
  def change
    add_column :form_templates, :powerbi_workspace_id, :string unless column_exists?(:form_templates, :powerbi_workspace_id)
    add_column :form_templates, :powerbi_report_id, :string unless column_exists?(:form_templates, :powerbi_report_id)
    remove_column :form_templates, :metabase_dashboard_id, :integer if column_exists?(:form_templates, :metabase_dashboard_id)
  end
end
