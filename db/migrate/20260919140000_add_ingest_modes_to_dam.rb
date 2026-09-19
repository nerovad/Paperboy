# frozen_string_literal: true

# A watch folder moved every file it ingested into _ingested. That is right for
# a drop folder and wrong for a library someone else maintains — a share whose
# files have to stay exactly where they are. So watching becomes a mode:
# 'move' is the old behaviour, 'leave' reads a folder without disturbing it,
# and an asset remembers the file it came from so a re-scan skips it.
#
# Locations may also state which formats they take, for uploads as well as
# scans; blank still means everything.
class AddIngestModesToDam < ActiveRecord::Migration[8.1]
  def up
    add_column :dam_storage_locations, :ingest_mode, :string, null: false, default: 'off'
    add_column :dam_storage_locations, :accepted_formats, :string
    # Where a leave-in-place scan got to, so a large tree is worked through in
    # batches across sweeps rather than walked from the top every minute.
    add_column :dam_storage_locations, :scan_cursor, :string

    execute "UPDATE dam_storage_locations SET ingest_mode = 'move' WHERE watch_enabled = 1"
    remove_column :dam_storage_locations, :watch_enabled

    add_column :dam_assets, :source_path, :string
    # The path digested, because the path itself is too long for an index key.
    add_column :dam_assets, :source_key, :string, limit: 64
    add_index :dam_assets, %i[storage_location_id source_key], unique: true,
                                                               where: 'source_key IS NOT NULL',
                                                               name: 'index_dam_assets_on_location_and_source'
  end

  def down
    remove_index :dam_assets, name: 'index_dam_assets_on_location_and_source'
    remove_column :dam_assets, :source_key
    remove_column :dam_assets, :source_path

    add_column :dam_storage_locations, :watch_enabled, :boolean, null: false, default: false
    execute "UPDATE dam_storage_locations SET watch_enabled = 1 WHERE ingest_mode <> 'off'"
    remove_column :dam_storage_locations, :scan_cursor
    remove_column :dam_storage_locations, :accepted_formats
    remove_column :dam_storage_locations, :ingest_mode
  end
end
