class CreateParkingLotSubmissions < ActiveRecord::Migration[8.0]
  def change
    create_table :parking_lot_submissions do |t|
      t.string :name
      t.string :phone
      t.string :employee_id
      t.string :email
      t.string :agency
      t.string :division
      t.string :department
      t.string :make
      t.string :model
      t.string :color
      t.string :year
      t.string :license_plate
      t.string :parking_lot
      t.string :old_permit_number

      t.timestamps
    end
  end
end
