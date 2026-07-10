class ConvertRemainingStatusColumnsToStrings < ActiveRecord::Migration[8.0]
  # Finish the status string-key migration for the remaining integer columns:
  # the two approval forms that were never on TrackableStatus (carpool,
  # work_schedule), the standalone help ticket open/closed enum, and the
  # vestigial unused status columns on database-type forms.
  TABLE_STATUS_MAP = {
    'carpool_forms' => { 0 => 'in_progress', 1 => 'step_1_pending', 2 => 'denied', 3 => 'approved' },
    'work_schedule_or_location_update_forms' => { 0 => 'in_progress', 1 => 'step_1_pending', 2 => 'step_2_pending', 3 => 'step_2_pending', 4 => 'approved', 5 => 'denied' },
    'help_tickets' => { 0 => 'open', 1 => 'closed' },
    'form_request_forms' => {},
    'gym_locker_forms' => {},
    'social_media_forms' => {}
  }.freeze

  def up
    # carpool was missing the approver_id column needed to appear in an inbox.
    add_column :carpool_forms, :approver_id, :string unless column_exists?(:carpool_forms, :approver_id)

    TABLE_STATUS_MAP.each do |table, mapping|
      default = (table == 'help_tickets' ? 'open' : 'in_progress')
      add_column table, :status_str, :string, default: default, null: false
      mapping.each do |int_val, key|
        execute("UPDATE #{quote_table_name(table)} SET status_str = #{quote(key)} WHERE status = #{Integer(int_val)}")
      end
      remove_column table, :status
      rename_column table, :status_str, :status
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          'Status columns were converted from integer to string keys; original ordinals are not recoverable.'
  end
end
