class MoveConditionalFieldsToParkingLotVehicles < ActiveRecord::Migration[8.0]
  def change
    add_column :parking_lot_vehicles, :carpool_participants, :text
    add_column :parking_lot_vehicles, :other_permit_type, :string, limit: 200
    remove_column :parking_lot_submissions, :carpool_participants, :text
    remove_column :parking_lot_submissions, :other_permit_type, :string, limit: 200
  end
end
