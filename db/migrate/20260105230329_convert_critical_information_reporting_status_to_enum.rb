class ConvertCriticalInformationReportingStatusToEnum < ActiveRecord::Migration[8.0]
  def up
    # Add new integer column for enum
    add_column :critical_information_reportings, :status_int, :integer, default: 0

    # Map existing string values to enum integers
    # in_progress: 0, resolved: 1, scheduled: 2, cancelled: 3
    execute <<-SQL
      UPDATE critical_information_reportings
      SET status_int = CASE
        WHEN status = 'In Progress' THEN 0
        WHEN status = 'Resolved' THEN 1
        WHEN status = 'Scheduled' THEN 2
        WHEN status = 'Cancelled' THEN 3
        ELSE 0
      END
    SQL

    # Remove old string column and rename new integer column
    remove_column :critical_information_reportings, :status
    rename_column :critical_information_reportings, :status_int, :status
  end

  def down
    # Add back string column
    add_column :critical_information_reportings, :status_str, :string

    # Map enum integers back to strings
    execute <<-SQL
      UPDATE critical_information_reportings
      SET status_str = CASE
        WHEN status = 0 THEN 'In Progress'
        WHEN status = 1 THEN 'Resolved'
        WHEN status = 2 THEN 'Scheduled'
        WHEN status = 3 THEN 'Cancelled'
        ELSE 'In Progress'
      END
    SQL

    # Remove integer column and rename string column back
    remove_column :critical_information_reportings, :status
    rename_column :critical_information_reportings, :status_str, :status
  end
end
