class AddTagsToFormTemplates < ActiveRecord::Migration[8.0]
  def change
    add_column :form_templates, :tags, :text
  end
end
