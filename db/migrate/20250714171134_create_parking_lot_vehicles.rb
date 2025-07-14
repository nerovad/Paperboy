class CreateParkingLotVehicles < ActiveRecord::Migration[8.0]
  def change
    create_table :parking_lot_vehicles do |t|
      t.references :parking_lot_submission, null: false, foreign_key: true
      t.string :make
      t.string :model
      t.string :color
      t.integer :year
      t.string :license_plate
      t.string :parking_lot

      t.timestamps
    end
  end
end
