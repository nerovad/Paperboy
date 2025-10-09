class AddDelegatedApproverToAuthorizationForms < ActiveRecord::Migration[7.0]
  def change
    add_column :authorization_forms, :supervisor_id, :string
    add_column :authorization_forms, :supervisor_email, :string
    add_column :authorization_forms, :delegated_approver_id, :string
    add_column :authorization_forms, :delegated_approver_email, :string
    add_column :authorization_forms, :approved_by, :string
    add_column :authorization_forms, :approved_at, :datetime
    add_column :authorization_forms, :delegated_approved_by, :string
    add_column :authorization_forms, :delegated_approved_at, :datetime
    add_column :authorization_forms, :denied_by, :string
    add_column :authorization_forms, :denied_at, :datetime
    add_column :authorization_forms, :denial_reason, :text
    add_column :authorization_forms, :status, :integer, default: 0
  end
end
