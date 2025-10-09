class AddAuthorizationFieldsToAuthorizationForms < ActiveRecord::Migration[7.0]
  def change
    add_column :authorization_forms, :service_type, :string
    add_column :authorization_forms, :key_type, :string
    add_column :authorization_forms, :budget_units, :string
  end
end
