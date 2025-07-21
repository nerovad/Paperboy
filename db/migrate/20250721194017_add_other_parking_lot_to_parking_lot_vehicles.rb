class AddOtherParkingLotToParkingLotVehicles < ActiveRecord::Migration[8.0]
  def change
    add_column :parking_lot_vehicles, :other_parking_lot, :string
  end
end
