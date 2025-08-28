# db/migrate/20250828_add_lifecycle_to_probation_transfer_requests.rb
class AddLifecycleToProbationTransferRequests < ActiveRecord::Migration[7.1]
  def change
    change_table :probation_transfer_requests do |t|
      t.datetime :expires_at, null: true   # created_at + 1.year defaulted in code
      t.datetime :canceled_at
      t.string   :canceled_reason, limit: 100
      t.bigint   :superseded_by_id         # points at the newer request that replaced this one
    end

    add_index :probation_transfer_requests, :expires_at
    add_index :probation_transfer_requests, :canceled_at
    add_index :probation_transfer_requests, :superseded_by_id
  end
end
