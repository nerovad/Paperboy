class MovePermitTypeToParkingLotVehicles < ActiveRecord::Migration[8.0]
  def change
    add_column :parking_lot_vehicles, :permit_type, :text
    remove_column :parking_lot_submissions, :permit_type, :text
  end
end
