# frozen_string_literal: true

# Storage locations existed as a search facet — somewhere an asset *is*. These
# three columns make them somewhere an asset *goes*, which is what the Storage
# screen manages.
class AddUploadTargetingToDamStorageLocations < ActiveRecord::Migration[8.0]
  def change
    # Where an ingest lands when nobody picked. One row carries it; setting it
    # on another moves it (see Dam::StorageLocation#demote_the_others).
    add_column :dam_storage_locations, :default_for_uploads, :boolean, null: false, default: false

    # Separate from `active`, because a location can serve files long after it
    # stops taking new ones — a sealed archive, a share that is full. Active
    # keeps it searchable and readable; this is what closes the door.
    add_column :dam_storage_locations, :read_only, :boolean, null: false, default: false

    # Nominal capacity, so the Storage table can show how full a place is
    # before someone finds out the hard way. Null means "not measured".
    add_column :dam_storage_locations, :quota_bytes, :bigint
  end
end
