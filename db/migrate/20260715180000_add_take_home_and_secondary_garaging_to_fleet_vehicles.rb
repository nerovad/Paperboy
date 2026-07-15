# frozen_string_literal: true

class AddTakeHomeAndSecondaryGaragingToFleetVehicles < ActiveRecord::Migration[8.0]
  def change
    # "Yes"/"No" — stored as a string to match the ['Yes', 'No'] select
    # convention used by the other forms rather than a tri-state boolean.
    add_column :fleet_vehicles, :take_home, :string, limit: 3

    # Optional second garaging site. Same limit as :garaging_location, since
    # both hold a Building#location_label.
    add_column :fleet_vehicles, :secondary_garaging_location, :string, limit: 200
  end
end
