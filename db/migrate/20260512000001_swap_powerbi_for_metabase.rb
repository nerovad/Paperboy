class SwapPowerbiForMetabase < ActiveRecord::Migration[8.0]
  def change
    add_column :form_templates, :metabase_dashboard_id, :integer unless column_exists?(:form_templates, :metabase_dashboard_id)
    remove_column :form_templates, :powerbi_workspace_id, :string if column_exists?(:form_templates, :powerbi_workspace_id)
    remove_column :form_templates, :powerbi_report_id, :string if column_exists?(:form_templates, :powerbi_report_id)
  end
end
