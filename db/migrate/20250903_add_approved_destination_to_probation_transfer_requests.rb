# db/migrate/20250903_add_approved_destination_to_probation_transfer_requests.rb
class AddApprovedDestinationToProbationTransferRequests < ActiveRecord::Migration[7.1]
  def change
    add_column :probation_transfer_requests, :approved_destination, :string
    add_index  :probation_transfer_requests, :approved_destination
  end
end
