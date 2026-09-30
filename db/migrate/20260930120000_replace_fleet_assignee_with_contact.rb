# frozen_string_literal: true

# The garaging form's "Assign To" became "Contact Name", and the vehicle's
# "Assigned To" -- always the legacy contact or the one a form named -- is
# renamed to match. The vehicle also records who last updated it.
# "Vehicle Assigned To" on the form is gone; its place is taken by a
# display-only lookup of the vehicle's Last Updated By.
class ReplaceFleetAssigneeWithContact < ActiveRecord::Migration[8.1]
  def change
    rename_column :fleet_vehicle_garaging_forms, :assign_to, :contact_name
    rename_column :fleet_vehicle_garaging_forms, :other_assignee, :other_contact
    remove_column :fleet_vehicle_garaging_forms, :vehicle_assigned_to, :string

    rename_column :fleet_vehicles, :assigned_to, :contact_name
    add_column :fleet_vehicles, :last_updated_by, :string

    reversible { |dir| dir.up { backfill_from_latest_forms } }
  end

  private

  # A vehicle a form has already updated was last updated by that form's
  # submitter. updated_at is left alone: nothing about the vehicle changed.
  def backfill_from_latest_forms
    execute <<~SQL.squish
      UPDATE v
      SET v.last_updated_by = f.name
      FROM fleet_vehicles v
      INNER JOIN fleet_vehicle_garaging_forms f ON f.id = v.fleet_vehicle_garaging_form_id
    SQL
  end
end
