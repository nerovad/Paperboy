# frozen_string_literal: true

class FleetVehicle < ApplicationRecord
  include Registry
  include AuditableEdits

  # Every edit, and the row being added or deleted, lands in its Records
  # history -- from the grid, the garaging form or the fleet import alike.
  audit_record_lifecycle!

  # The fleet master: one row per vehicle, loaded by fleet:import_garaging and
  # edited in place -- from the Records grid, or by a submitted garaging form
  # (see #apply_garaging_form!). The link names the last form that did so.
  belongs_to :fleet_vehicle_garaging_form, optional: true
  # Every garaging form filed against the vehicle. Deleting the vehicle keeps
  # them, still naming it by vehicle_number.
  has_many :garaging_forms, class_name: 'FleetVehicleGaragingForm', dependent: :nullify

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
  registry_column :secondary_garaging_location, label: 'Secondary Garaging Location', kind: :text
  registry_column :take_home, label: 'Take Home', kind: :text
  registry_column :updated_at, label: 'Last Updated', kind: :datetime
  registry_column :last_updated_by, label: 'Last Updated By', kind: :text

  # Whoever changes a vehicle is recorded as its last updater, by employee id
  # and by name: the signed-in user for a Records grid edit, the submitter for a
  # garaging form. The fleet import runs with nobody signed in and leaves it as
  # it was.
  before_save :stamp_last_updated_by, unless: :will_save_change_to_last_updated_by?

  # How the vehicle is named in the Records change log: its fleet number, or
  # its plate for a vehicle that has none yet.
  def vehicle_label
    vehicle_number.presence || license_plate
  end

  # Copies a submitted garaging form's answers onto this vehicle. A question
  # left blank keeps what is on file; answering "No" to a secondary location
  # clears it. The submitter, from the form's first page, becomes the vehicle's
  # Last Updated By.
  def apply_garaging_form!(form)
    secondary = case form.do_you_have_a_secondary_location
                when 'Yes' then form.secondary_garaging_location
                when 'No' then nil
                else secondary_garaging_location
                end

    update!(
      last_updated_by: form.name,
      last_updated_by_employee_id: form.employee_id.presence&.to_i,
      take_home: form.is_this_a_take_home_vehicle.presence || take_home,
      garaging_location: form.garaging_location.presence || garaging_location,
      secondary_garaging_location: secondary,
      fleet_vehicle_garaging_form: form
    )
  end

  private

  def stamp_last_updated_by
    name = current_user_display_name
    return unless name && changed?

    self.last_updated_by = name
    self.last_updated_by_employee_id = Current.user['employee_id'].presence&.to_i
  end
end
