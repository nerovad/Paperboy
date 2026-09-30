# frozen_string_literal: true

# A garaging form now points at its vehicle by id rather than only by the
# vehicle_number text, and a vehicle records who last updated it by employee
# id as well as by name -- the name stays as the snapshot the grid shows.
# Contact Name is no longer collected, so its columns go.
class LinkFleetFormsAndUpdatersById < ActiveRecord::Migration[8.1]
  # Plain classes, so the backfill does not depend on the app models' callbacks
  # or on columns they may reference later.
  class FleetVehicle < ActiveRecord::Base
    self.table_name = 'fleet_vehicles'
  end

  def change
    add_reference :fleet_vehicle_garaging_forms, :fleet_vehicle, foreign_key: true
    add_column :fleet_vehicles, :last_updated_by_employee_id, :integer

    remove_column :fleet_vehicle_garaging_forms, :contact_name, :string
    remove_column :fleet_vehicle_garaging_forms, :other_contact, :string
    remove_column :fleet_vehicles, :contact_name, :string

    reversible { |dir| dir.up { backfill } }
  end

  private

  def backfill
    execute <<~SQL.squish
      UPDATE f SET f.fleet_vehicle_id = v.id
      FROM fleet_vehicle_garaging_forms f
      INNER JOIN fleet_vehicles v ON v.vehicle_number = f.vehicle_number
    SQL

    execute <<~SQL.squish
      UPDATE v SET v.last_updated_by_employee_id = TRY_CAST(f.employee_id AS int)
      FROM fleet_vehicles v
      INNER JOIN fleet_vehicle_garaging_forms f ON f.id = v.fleet_vehicle_garaging_form_id
    SQL

    backfill_updaters_by_name
  end

  # Employees live in GSABSS, which cannot be joined from here, so a name with
  # no id yet is matched in Ruby -- and only when exactly one employee has it.
  def backfill_updaters_by_name
    FleetVehicle.where(last_updated_by_employee_id: nil).where.not(last_updated_by: [nil, ''])
                .distinct.pluck(:last_updated_by).each do |name|
      first, last = name.split(' ', 2)
      ids = Employee.where(first_name: first, last_name: last).limit(2).pluck(:id)
      next unless ids.one?

      FleetVehicle.where(last_updated_by_employee_id: nil, last_updated_by: name)
                  .update_all(last_updated_by_employee_id: ids.first)
    end
  end
end
