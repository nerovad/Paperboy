class AddSupervisorIdToParkingLotSubmissions < ActiveRecord::Migration[8.0]
  def change
    add_column :parking_lot_submissions, :supervisor_id, :string
  end
end
