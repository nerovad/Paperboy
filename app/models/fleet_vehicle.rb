# frozen_string_literal: true

class FleetVehicle < ApplicationRecord
  include Registry
  include AuditableEdits

  # Every edit, and the row being added or deleted, lands in its Records
  # history -- from the grid, the garaging form or the fleet import alike.
  audit_record_lifecycle!

  # The fleet master: one row per vehicle, loaded by fleet:import_garaging and
  # edited in place -- from the Records grid, or by an approved garaging form
  # (see #apply_garaging_form!). The link names the last form that did so.
  belongs_to :fleet_vehicle_garaging_form, optional: true

  # Records table definition — surfaced as the "records:fleet" page and served
  # by the generic records grid (no bespoke route). Garaging forms update rows
  # rather than add them, so there is no registry_fed_by.
  registry_table slug: 'fleet', label: 'Fleet Vehicles',
                 dropdown_key: 'fleet_inventory',
                 row_label: :vehicle_label

  registry_column :vehicle_number, label: 'Vehicle #', kind: :text
  registry_column :agency, kind: :text, filter: :select
  registry_column :budget_unit, label: 'Unit', kind: :text, filter: :select
  registry_column :year, kind: :text
  registry_column :make, kind: :text, filter: :select
  registry_column :model, kind: :text
  registry_column :color, kind: :text
  registry_column :license_plate, label: 'Plate', kind: :text
  registry_column :garaging_location, label: 'Garaging Location', kind: :text
  registry_column :take_home, label: 'Take Home', kind: :text
  registry_column :assigned_to, label: 'Assigned To', kind: :text

  # How the vehicle is named in the Records change log: its fleet number, or
  # its plate for a vehicle that has none yet.
  def vehicle_label
    vehicle_number.presence || license_plate
  end

  # Copies an approved garaging form's answers onto this vehicle. A question
  # left blank keeps what is on file; answering "No" to a secondary location
  # clears it. Assigned To is not touched: the form only displays it.
  def apply_garaging_form!(form)
    secondary = case form.do_you_have_a_secondary_location
                when 'Yes' then form.secondary_garaging_location
                when 'No' then nil
                else secondary_garaging_location
                end

    update!(
      take_home: form.is_this_a_take_home_vehicle.presence || take_home,
      garaging_location: form.garaging_location.presence || garaging_location,
      secondary_garaging_location: secondary,
      fleet_vehicle_garaging_form: form
    )
  end
end
