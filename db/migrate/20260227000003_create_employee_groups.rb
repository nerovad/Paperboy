class CreateEmployeeGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :employee_groups do |t|
      t.integer :employee_id, null: false
      t.bigint :group_id, null: false
      t.datetime :assigned_at, default: -> { "CURRENT_TIMESTAMP" }
      t.integer :assigned_by
    end

    add_index :employee_groups, [:employee_id, :group_id], unique: true
    add_foreign_key :employee_groups, :employees, column: :employee_id, primary_key: :employee_id
    add_foreign_key :employee_groups, :groups
  end
end
