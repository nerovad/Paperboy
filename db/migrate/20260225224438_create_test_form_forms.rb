class CreateTestFormForms < ActiveRecord::Migration[7.1]
  def change
    create_table :test_form_forms do |t|
      # Baseline fields for your two-page template
      t.string :employee_id
      t.string :name
      t.string :phone
      t.string :email

      t.string :agency
      t.string :division
      t.string :department
      t.string :unit

      t.integer :status, default: 0

      # Approval workflow fields
      t.string :approver_id       # Current approver's employee ID
      t.text :deny_reason         # Reason for denial (if denied)

      t.timestamps
    end

    add_index :test_form_forms, :approver_id
    add_index :test_form_forms, :employee_id
  end
end
