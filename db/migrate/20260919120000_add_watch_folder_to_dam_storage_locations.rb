# frozen_string_literal: true

# Root used to be a note — nothing read it — and is now the folder a disk or
# share location stores its files in. A blank root means "the app's own Active
# Storage folder", which is what the seeded Local disk location always was, so
# the two values that seed ever wrote are cleared rather than turned into a
# second service pointing at the same place.
#
# The watch folder is the other half: somewhere files can be dropped to be
# ingested into the location without the upload form.
class AddWatchFolderToDamStorageLocations < ActiveRecord::Migration[8.1]
  def up
    add_column :dam_storage_locations, :watch_path, :string
    add_column :dam_storage_locations, :watch_enabled, :boolean, null: false, default: false

    seeded_roots = [Rails.root.join('storage').to_s, Rails.root.join('storage', Rails.env).to_s]
    execute <<~SQL.squish
      UPDATE dam_storage_locations SET root = NULL
      WHERE root IN (#{seeded_roots.map { |root| connection.quote(root) }.join(', ')})
    SQL
  end

  def down
    remove_column :dam_storage_locations, :watch_enabled
    remove_column :dam_storage_locations, :watch_path
  end
end
