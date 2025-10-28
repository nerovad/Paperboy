# db/migrate/XXXXXX_create_authorized_approvers.rb
class CreateAuthorizedApprovers < ActiveRecord::Migration[7.0]
  def change
    create_table :authorized_approvers do |t|
      t.string :employee_id, null: false
      t.string :department_id, null: false
      t.string :service_type, null: false
      t.string :key_type
      t.string :span
      t.text :budget_units
      t.text :locations
      t.string :authorized_by
      t.timestamps
    end
    
    add_index :authorized_approvers, [:department_id, :service_type]
    add_index :authorized_approvers, :employee_id
  end
end
