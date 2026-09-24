# frozen_string_literal: true

# The garaging form now asks who the vehicle should be assigned to (an
# employee, or "Other" with a typed name) and shows where the vehicle was last
# garaged. Assign To is copied onto the vehicle on approval; Last Known
# Location is a snapshot of the vehicle's garaging location at submission.
class AddAssigneeFieldsToFleetVehicleGaragingForms < ActiveRecord::Migration[8.1]
  def change
    change_table :fleet_vehicle_garaging_forms, bulk: true do |t|
      t.string :assign_to
      t.string :other_assignee
      t.string :last_known_location, limit: 200
    end
  end
end
