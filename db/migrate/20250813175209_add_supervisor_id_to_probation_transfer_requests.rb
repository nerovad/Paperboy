class AddSupervisorIdToProbationTransferRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :probation_transfer_requests, :supervisor_id, :string
  end
end
