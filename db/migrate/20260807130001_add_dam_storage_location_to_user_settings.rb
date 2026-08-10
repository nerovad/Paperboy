# frozen_string_literal: true

# Which storage location this person's DAM uploads default to. Personal rather
# than global because two people ingesting on the same day are often filling
# different buckets — one loading a campaign shoot, one draining a camera card
# into cold storage.
#
# A pointer, not a copy: null means "follow the library default", and a
# location that is later disabled falls back rather than going stale, so no
# backfill is needed here or when a location is retired.
class AddDamStorageLocationToUserSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :user_settings, :dam_storage_location_id, :integer
  end
end
