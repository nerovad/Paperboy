class AddReadOnlyToFormFields < ActiveRecord::Migration[8.0]
  def change
    add_column :form_fields, :read_only, :string, default: "none"
  end
end
