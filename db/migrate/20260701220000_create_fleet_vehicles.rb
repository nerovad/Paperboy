class CreateFleetVehicles < ActiveRecord::Migration[7.1]
  def change
    create_table :fleet_vehicles do |t|
      t.bigint :fleet_vehicle_garaging_form_id, null: false
      t.integer :year
      t.string :make, limit: 50
      t.string :model, limit: 50
      t.string :color, limit: 20
      t.string :license_plate, limit: 15
      t.string :garaging_location, limit: 200

      t.timestamps
    end

    add_index :fleet_vehicles, :fleet_vehicle_garaging_form_id

    # The generated baseline never added a column for the page-4 "location"
    # builder field; add it so the form renders. (Garaging location is now
    # captured per-vehicle above, so this form-level field is likely redundant.)
    add_column :fleet_vehicle_garaging_forms, :location, :string
  end
end
