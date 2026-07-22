# frozen_string_literal: true

class SyncSectionsFleetVehicleGaragingForm < ActiveRecord::Migration[7.1]
  def change
    create_table :fleet_vehicle_garaging_form_locations do |t|
      t.bigint :fleet_vehicle_garaging_form_id, null: false
      t.string :location
      t.timestamps
    end
    add_index :fleet_vehicle_garaging_form_locations, :fleet_vehicle_garaging_form_id
  end
end
