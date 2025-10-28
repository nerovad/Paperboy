# db/migrate/XXXXXX_drop_old_authorization_forms_columns.rb
class DropOldAuthorizationFormsColumns < ActiveRecord::Migration[7.0]
  def change
    # Keep the table but remove all the old workflow columns
    remove_column :authorization_forms, :employee_id, :string
    remove_column :authorization_forms, :name, :string
    remove_column :authorization_forms, :phone, :string
    remove_column :authorization_forms, :email, :string
    remove_column :authorization_forms, :agency, :string
    remove_column :authorization_forms, :division, :string
    remove_column :authorization_forms, :department, :string
    remove_column :authorization_forms, :unit, :string
    remove_column :authorization_forms, :supervisor_id, :string
    remove_column :authorization_forms, :supervisor_email, :string
    remove_column :authorization_forms, :delegated_approver_id, :string
    remove_column :authorization_forms, :delegated_approver_email, :string
    remove_column :authorization_forms, :approved_by, :string
    remove_column :authorization_forms, :approved_at, :datetime
    remove_column :authorization_forms, :delegated_approved_by, :string
    remove_column :authorization_forms, :delegated_approved_at, :datetime
    remove_column :authorization_forms, :denied_by, :string
    remove_column :authorization_forms, :denied_at, :datetime
    remove_column :authorization_forms, :denial_reason, :text
    remove_column :authorization_forms, :status, :integer
    remove_column :authorization_forms, :key_type, :string
    remove_column :authorization_forms, :budget_units, :string
  end
end
