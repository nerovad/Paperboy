class AddInboxButtonsToFormTemplates < ActiveRecord::Migration[8.0]
  def change
    add_column :form_templates, :inbox_buttons, :json
  end
end
