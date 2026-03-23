class RemoveAccessControlFromFormTemplates < ActiveRecord::Migration[8.0]
  def change
    remove_column :form_templates, :access_level, :string, default: 'public'
    remove_column :form_templates, :acl_group_id, :bigint
    remove_column :form_templates, :org_scope_type, :string
    remove_column :form_templates, :org_scope_id, :string
  end
end
