class AddHasCustomViewToFormFields < ActiveRecord::Migration[8.0]
  def change
    add_column :form_fields, :has_custom_view, :boolean, default: false, null: false
  end
end
