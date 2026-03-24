class AddVisibilityToFormTemplates < ActiveRecord::Migration[8.0]
  def change
    add_column :form_templates, :visibility, :string, default: 'restricted', null: false
  end
end
