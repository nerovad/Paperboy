class CreateBikeLockerForms < ActiveRecord::Migration[7.1]
  def change
    create_table :bike_locker_forms do |t|
      # Baseline fields for your two-page template
      # NOTE: Column names MUST start with a letter or underscore (not a number).
      # e.g. use :spending_limit_30_day instead of :30_day_spending_limit
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

    add_index :bike_locker_forms, :approver_id
    add_index :bike_locker_forms, :employee_id
  end
end
