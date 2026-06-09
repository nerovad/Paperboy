class AddAllLocationsToAuthorizedApprovers < ActiveRecord::Migration[8.0]
  # Mirrors all_budget_units: an explicit "all locations" flag instead of
  # leaning on a blank locations list (which now means "none / incomplete").
  # Locations only apply to Facility Keys (service type K). Guarded with
  # column_exists? for environments altered by hand.
  def up
    unless column_exists?(:authorized_approvers, :all_locations)
      add_column :authorized_approvers, :all_locations, :boolean, default: false, null: false
    end
  end

  def down
    remove_column :authorized_approvers, :all_locations if column_exists?(:authorized_approvers, :all_locations)
  end
end
