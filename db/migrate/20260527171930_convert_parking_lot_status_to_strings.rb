# frozen_string_literal: true

class ConvertParkingLotStatusToStrings < ActiveRecord::Migration[8.0]
  # Phase 5 (parking lot): convert the custom integer status to string keys and
  # retire sent_to_security. The final approved state now surfaces to the
  # GSA_Security group's inbox (see InboxController#scope_group_visible) instead
  # of a dedicated status. submitted -> in_progress; the old approved(3) and
  # sent_to_security(4) both collapse to "approved"; legacy NULL rows take the
  # default "in_progress".
  STATUS_MAPPING = {
    0 => 'in_progress',
    1 => 'pending_delegated_approval',
    2 => 'denied',
    3 => 'approved',
    4 => 'approved'
  }.freeze

  def up
    template = FormTemplate.find_by(class_name: 'ParkingLotSubmission')
    template&.statuses&.where(key: 'sent_to_security')&.destroy_all

    add_column :parking_lot_submissions, :status_str, :string, default: 'in_progress', null: false
    STATUS_MAPPING.each do |int_val, key|
      execute("UPDATE #{quote_table_name('parking_lot_submissions')} SET status_str = #{quote(key)} WHERE status = #{Integer(int_val)}")
    end
    remove_column :parking_lot_submissions, :status
    rename_column :parking_lot_submissions, :status_str, :status
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          'Parking lot status was converted from integer to string keys; original ordinals are not recoverable.'
  end
end
