class AddEmployeeIdToLoaForms < ActiveRecord::Migration[7.1]
  def up
    # Add employee_id column if it doesn't exist
    add_column :loa_forms, :employee_id, :string unless column_exists?(:loa_forms, :employee_id)

    # Backfill from events (event_id → events → employee_id)
    execute <<~SQL
      UPDATE lf
      SET lf.employee_id = ev.employee_id
      FROM dbo.loa_forms lf
      INNER JOIN dbo.events ev ON ev.id = lf.event_id
      WHERE lf.employee_id IS NULL OR lf.employee_id = '';
    SQL

    # Optional: add index for faster lookups
    add_index :loa_forms, :employee_id unless index_exists?(:loa_forms, :employee_id)

    # Optional: add FK constraint to enforce data integrity
    # Only do this if employee_id values match EmployeeID in the employees table
    # remove the comment if you're ready to enforce it:
    # add_foreign_key :loa_forms, :employees, column: :employee_id, primary_key: :EmployeeID
  end

  def down
    # Remove index and column if rollback
    remove_index :loa_forms, :employee_id if index_exists?(:loa_forms, :employee_id)
    remove_column :loa_forms, :employee_id if column_exists?(:loa_forms, :employee_id)
  end
end
