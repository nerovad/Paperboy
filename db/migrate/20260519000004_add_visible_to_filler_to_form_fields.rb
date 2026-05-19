class AddVisibleToFillerToFormFields < ActiveRecord::Migration[8.0]
  def change
    add_column :form_fields, :visible_to_filler, :boolean, default: false, null: false
  end
end
