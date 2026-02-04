class AddOrgScopeToFormTemplates < ActiveRecord::Migration[7.1]
  def change
    add_column :form_templates, :org_scope_type, :string
    add_column :form_templates, :org_scope_id, :string
  end
end
