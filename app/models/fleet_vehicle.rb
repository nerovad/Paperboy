# frozen_string_literal: true

class FleetVehicle < ApplicationRecord
  include Registry

  belongs_to :fleet_vehicle_garaging_form

  # Records table definition — surfaced as the "records:fleet" page and served
  # by the generic records grid (no bespoke route). Vehicles are created via
  # the garaging form's nested attributes, so there is no registry_fed_by; this
  # table is a live view over the rows that already exist.
  registry_table slug: 'fleet', label: 'Fleet Vehicles',
                 dropdown_key: 'fleet_inventory',
                 includes: :fleet_vehicle_garaging_form

  registry_column :year, kind: :text
  registry_column :make, kind: :text, filter: :select
  registry_column :model, kind: :text
  registry_column :color, kind: :text
  registry_column :license_plate, label: 'Plate', kind: :text, filter: :search
  registry_column :garaging_location, label: 'Garaging Location', kind: :text
  registry_column :take_home, label: 'Take Home', kind: :text
  registry_column :owner_name, label: 'Assigned To', kind: :text, filter: :search
  registry_column :owner_agency, label: 'Agency', kind: :text, filter: :select
  registry_column :status_label, label: 'Status', kind: :status, sortable: false

  # --- Owner / status delegated from the parent garaging form ---

  def owner_name
    fleet_vehicle_garaging_form&.name
  end

  def owner_agency
    fleet_vehicle_garaging_form&.agency
  end

  # Human label for the parent submission's approval status.
  def status_label
    fleet_vehicle_garaging_form&.status.to_s.tr('_', ' ').titleize.presence || '—'
  end

  # Badge category for the Records "Status" column (drives the badge color).
  def status_badge_category
    case fleet_vehicle_garaging_form&.status
    when 'approved' then :approved
    when 'denied' then :denied
    when 'step_1_pending' then :in_review
    else :pending
    end
  end
end
