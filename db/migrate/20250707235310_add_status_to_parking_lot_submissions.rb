class AddStatusToParkingLotSubmissions < ActiveRecord::Migration[8.0]
  def change
    add_column :parking_lot_submissions, :status, :integer
  end
end
