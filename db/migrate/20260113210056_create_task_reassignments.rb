class CreateTaskReassignments < ActiveRecord::Migration[8.0]
  def change
    create_table :task_reassignments do |t|
      # Polymorphic association to tasks
      t.string :task_type, null: false
      t.bigint :task_id, null: false

      # Reassignment details
      t.string :from_employee_id, null: false
      t.string :to_employee_id, null: false
      t.string :reassigned_by_id, null: false
      t.text :reason

      # Which field was updated (handles different assignment field names)
      t.string :assignment_field

      t.timestamps
    end

    # Indexes for performance
    add_index :task_reassignments, [:task_type, :task_id]
    add_index :task_reassignments, :to_employee_id
    add_index :task_reassignments, :from_employee_id
  end
end
