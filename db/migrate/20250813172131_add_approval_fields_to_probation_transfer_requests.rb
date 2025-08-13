class AddApprovalFieldsToProbationTransferRequests < ActiveRecord::Migration[7.1]
  def up
    # status
    if column_exists?(:probation_transfer_requests, :status)
      change_column_default :probation_transfer_requests, :status, 0
      execute "UPDATE probation_transfer_requests SET status = 0 WHERE status IS NULL"
      change_column_null :probation_transfer_requests, :status, false
    else
      add_column :probation_transfer_requests, :status, :integer, default: 0, null: false
    end
    add_index :probation_transfer_requests, :status unless index_exists?(:probation_transfer_requests, :status)

    # the rest — only add if missing
    add_column :probation_transfer_requests, :approved_by, :string unless column_exists?(:probation_transfer_requests, :approved_by)
    add_column :probation_transfer_requests, :approved_at, :datetime unless column_exists?(:probation_transfer_requests, :approved_at)
    add_column :probation_transfer_requests, :denied_by, :string unless column_exists?(:probation_transfer_requests, :denied_by)
    add_column :probation_transfer_requests, :denied_at, :datetime unless column_exists?(:probation_transfer_requests, :denied_at)
    add_column :probation_transfer_requests, :denial_reason, :text unless column_exists?(:probation_transfer_requests, :denial_reason)
    add_column :probation_transfer_requests, :supervisor_email, :string unless column_exists?(:probation_transfer_requests, :supervisor_email)
  end

  def down
    remove_index :probation_transfer_requests, :status if index_exists?(:probation_transfer_requests, :status)

    # only remove columns we added
    [:approved_by, :approved_at, :denied_by, :denied_at, :denial_reason, :supervisor_email].each do |col|
      remove_column :probation_transfer_requests, col if column_exists?(:probation_transfer_requests, col)
    end

    # don't drop status if it pre-existed; just revert default to nil
    change_column_default :probation_transfer_requests, :status, nil if column_exists?(:probation_transfer_requests, :status)
  end
end
