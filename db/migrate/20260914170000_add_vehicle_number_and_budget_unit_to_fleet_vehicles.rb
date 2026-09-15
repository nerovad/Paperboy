# frozen_string_literal: true

class AddVehicleNumberAndBudgetUnitToFleetVehicles < ActiveRecord::Migration[8.1]
  def change
    # County fleet number from the legacy Fleet garaging list. Unique in
    # practice, and the key fleet:import_garaging uses to find its own rows.
    add_column :fleet_vehicles, :vehicle_number, :string, limit: 20
    add_index :fleet_vehicles, :vehicle_number

    # Budget unit the vehicle is charged to; matches Coa::Unit#unit_id.
    add_column :fleet_vehicles, :budget_unit, :string, limit: 10
  end
end
