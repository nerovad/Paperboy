class AddConditionalLogicToFormFields < ActiveRecord::Migration[8.0]
  def change
    # conditional_field_id: references another form_field (must be a dropdown)
    # conditional_values: JSON array of values that make this field visible
    # Example: if dropdown field has ["A", "B", "C"] and conditional_values is ["A", "B"],
    #          this field only shows when A or B is selected
    add_column :form_fields, :conditional_field_id, :integer
    add_column :form_fields, :conditional_values, :json

    add_index :form_fields, :conditional_field_id
  end
end
