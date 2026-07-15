# frozen_string_literal: true

# FleetVehicleGaragingForm declares a string-valued `enum :status`, but its
# generated table got `t.integer :status, default: 0`. The integer type cast
# every enum value ("in_progress") to nil, so TrackableStatus#record_initial_status
# built a StatusChange with a blank to_status and its create! rolled the whole
# insert back — the form could never be submitted.
#
# Every other TrackableStatus form already stores status as a string
# (default 'in_progress', null: false); this brings garaging in line. The table
# is empty, so no backfill is needed.
class ChangeFleetVehicleGaragingFormsStatusToString < ActiveRecord::Migration[8.0]
  def up
    # SQL Server won't ALTER a column that still has a default constraint bound to
    # it, and it drops rather than rewrites that constraint — so the default has to
    # be re-applied as its own step afterwards, not via change_column's :default.
    change_column_default :fleet_vehicle_garaging_forms, :status, from: 0, to: nil
    change_column :fleet_vehicle_garaging_forms, :status, :string, null: false
    change_column_default :fleet_vehicle_garaging_forms, :status, from: nil, to: 'in_progress'
  end

  def down
    change_column_default :fleet_vehicle_garaging_forms, :status, from: 'in_progress', to: nil
    change_column :fleet_vehicle_garaging_forms, :status, :integer, default: 0
  end
end
