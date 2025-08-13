class AddOtherTransferDestinationToProbationTransferRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :probation_transfer_requests, :other_transfer_destination, :string
  end
end
