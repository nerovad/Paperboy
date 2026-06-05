class CreateSupportTables < ActiveRecord::Migration[8.0]
  def change
    # Authorization Managers
    create_table :authorization_managers do |t|
      t.string :employee_id, null: false
      t.string :department_id, null: false
      t.timestamps
    end
    add_index :authorization_managers, [:employee_id, :department_id], unique: true

    # Authorized Approvers
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
    add_index :authorized_approvers, :employee_id
    add_index :authorized_approvers, [:department_id, :service_type]

    # Status Changes (polymorphic)
    create_table :status_changes do |t|
      t.string :trackable_type, null: false
      t.bigint :trackable_id, null: false
      t.string :from_status
      t.string :to_status, null: false
      t.string :changed_by_id
      t.string :changed_by_name
      t.text :notes
      t.timestamps
    end
    add_index :status_changes, [:trackable_type, :trackable_id]
    add_index :status_changes, :changed_by_id

    # Task Reassignments (polymorphic)
    create_table :task_reassignments do |t|
      t.string :task_type, null: false
      t.bigint :task_id, null: false
      t.string :from_employee_id, null: false
      t.string :to_employee_id, null: false
      t.string :reassigned_by_id, null: false
      t.text :reason
      t.string :assignment_field
      t.timestamps
    end
    add_index :task_reassignments, [:task_type, :task_id]
    add_index :task_reassignments, :from_employee_id
    add_index :task_reassignments, :to_employee_id

    # Saved Searches
    create_table :saved_searches do |t|
      t.string :employee_id, null: false
      t.string :name, null: false
      t.text :filters, null: false
      t.timestamps
    end
    add_index :saved_searches, :employee_id
    add_index :saved_searches, [:employee_id, :name], unique: true

    # Scheduled Reports
    create_table :scheduled_reports do |t|
      t.string :employee_id, null: false
      t.string :form_type, null: false
      t.string :format, default: "csv", null: false
      t.string :status_filter
      t.string :frequency, null: false
      t.string :time_of_day, null: false
      t.integer :day_of_week
      t.integer :day_of_month
      t.string :date_range_type, null: false
      t.boolean :enabled, default: true, null: false
      t.datetime :last_run_at
      t.datetime :next_run_at
      t.timestamps
    end
    add_index :scheduled_reports, :employee_id
    add_index :scheduled_reports, :enabled
    add_index :scheduled_reports, :next_run_at

    # Help Tickets
    create_table :help_tickets do |t|
      t.string :subject, null: false
      t.text :description, null: false
      t.string :employee_id, null: false
      t.string :employee_name
      t.string :employee_email
      t.integer :status, default: 0, null: false
      t.timestamps
    end
    add_index :help_tickets, :employee_id
  end
end
