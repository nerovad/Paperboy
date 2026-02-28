class ReplacePowerbiWithMetabase < ActiveRecord::Migration[8.0]
  def change
    add_column :form_templates, :metabase_dashboard_id, :integer
    remove_column :form_templates, :powerbi_workspace_id, :string
    remove_column :form_templates, :powerbi_report_id, :string
  end
end
