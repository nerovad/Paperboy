# frozen_string_literal: true

# A garaging form now covers exactly one vehicle from the fleet list, so its
# answers live on the submission itself rather than in nested fleet_vehicles
# rows. On approval they are copied onto that vehicle (FleetVehicle is the
# fleet master). These are the columns the form builder's fields write.
class AddVehicleFieldsToFleetVehicleGaragingForms < ActiveRecord::Migration[8.1]
  def change
    change_table :fleet_vehicle_garaging_forms, bulk: true do |t|
      t.string :vehicle_number, limit: 20
      t.integer :year
      t.string :make, limit: 50
      t.string :model, limit: 50
      t.string :vehicle_assigned_to
      t.string :is_this_a_take_home_vehicle, limit: 3
      t.string :other_location, limit: 200
      t.string :do_you_have_a_secondary_location, limit: 3
      t.string :secondary_location, limit: 200
      t.string :other_secondary_location, limit: 200
    end
    add_index :fleet_vehicle_garaging_forms, :vehicle_number
  end
end
