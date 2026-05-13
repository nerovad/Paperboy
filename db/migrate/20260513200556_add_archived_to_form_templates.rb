class AddArchivedToFormTemplates < ActiveRecord::Migration[8.0]
  def change
    add_column :form_templates, :archived, :boolean, default: false, null: false
    add_index :form_templates, :archived
  end
end
