# frozen_string_literal: true

# fleet_vehicles becomes the fleet master: one row per vehicle, updated in
# place when a garaging form for it is approved. Until now each row belonged
# to a submission and read "Assigned To" and "Agency" through it; both become
# real columns here, backfilled from that submission.
#
# The submission link stays as the last form that updated the vehicle, so it
# turns optional -- fleet:import_garaging loads vehicles without one.
class MakeFleetVehiclesTheFleetMaster < ActiveRecord::Migration[8.1]
  def up
    duplicates = select_values(<<~SQL.squish)
      SELECT vehicle_number FROM fleet_vehicles
      WHERE vehicle_number IS NOT NULL
      GROUP BY vehicle_number HAVING COUNT(*) > 1
    SQL
    if duplicates.any?
      raise ActiveRecord::MigrationError,
            "fleet_vehicles has duplicate vehicle numbers (#{duplicates.first(20).join(', ')}); " \
            'resolve them by hand before making vehicle_number unique'
    end

    change_table :fleet_vehicles, bulk: true do |t|
      t.string :assigned_to
      t.string :agency
    end

    execute <<~SQL.squish
      UPDATE v SET v.assigned_to = f.name, v.agency = f.agency
      FROM fleet_vehicles v
      JOIN fleet_vehicle_garaging_forms f ON f.id = v.fleet_vehicle_garaging_form_id
    SQL

    change_column_null :fleet_vehicles, :fleet_vehicle_garaging_form_id, true

    remove_index :fleet_vehicles, :vehicle_number
    add_index :fleet_vehicles, :vehicle_number, unique: true, where: 'vehicle_number IS NOT NULL'
  end

  def down
    remove_index :fleet_vehicles, :vehicle_number
    add_index :fleet_vehicles, :vehicle_number

    change_column_null :fleet_vehicles, :fleet_vehicle_garaging_form_id, false

    change_table :fleet_vehicles, bulk: true do |t|
      t.remove :assigned_to, :agency
    end
  end
end
