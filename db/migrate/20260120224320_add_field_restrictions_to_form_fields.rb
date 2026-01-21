class AddFieldRestrictionsToFormFields < ActiveRecord::Migration[8.0]
  def change
    # Type can be: 'none' (anyone/submitter), 'employee', 'group'
    add_column :form_fields, :restricted_to_type, :string, default: 'none'
    add_column :form_fields, :restricted_to_employee_id, :integer
    add_column :form_fields, :restricted_to_group_id, :integer

    add_index :form_fields, :restricted_to_type
  end
end
