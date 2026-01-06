class AddPowerbiFieldsToFormTemplates < ActiveRecord::Migration[8.0]
  def change
    add_column :form_templates, :powerbi_workspace_id, :string
    add_column :form_templates, :powerbi_report_id, :string
    add_column :form_templates, :has_dashboard, :boolean, default: false
  end
end
