# frozen_string_literal: true

# Ingesting a share used to copy every file into the library, which for a
# 25GB filestore means holding it twice. A referenced asset instead records
# where the file is and never copies it: what the DAM stores, and what it
# shows, is a proxy and a thumbnail built once at ingest — or adopted, when
# whatever wrote the share has already made them.
#
# 'leave' becomes 'reference', since reading a folder without moving anything
# and copying all of it was never a combination anybody asked for.
class ReferenceOriginalsAndAddDerivatives < ActiveRecord::Migration[8.1]
  def up
    add_column :dam_assets, :storage_kind, :string, null: false, default: 'stored'
    add_column :dam_assets, :derivative_state, :string, null: false, default: 'pending'
    add_column :dam_assets, :derivative_error, :text

    # Filename globs a scan passes over, for the generated files that sit
    # beside originals — ResourceSpace writes five previews per resource.
    add_column :dam_storage_locations, :ignore_patterns, :string

    execute "UPDATE dam_storage_locations SET ingest_mode = 'reference' WHERE ingest_mode = 'leave'"
    execute "UPDATE dam_assets SET storage_kind = 'stored' WHERE storage_kind IS NULL"

    # A file that cannot be ingested is remembered, or every scan of the tree
    # tries it again and writes another failed job for it.
    create_table :dam_ingest_failures do |t|
      t.references :storage_location, null: false, foreign_key: { to_table: :dam_storage_locations }
      t.string :source_key, null: false, limit: 64
      t.string :source_path
      t.text :reason
      t.integer :attempts, null: false, default: 1
      t.datetime :last_failed_at
      t.timestamps
    end
    add_index :dam_ingest_failures, %i[storage_location_id source_key], unique: true,
                                                                        name: 'index_dam_ingest_failures_on_location_and_source'
  end

  def down
    drop_table :dam_ingest_failures
    execute "UPDATE dam_storage_locations SET ingest_mode = 'leave' WHERE ingest_mode = 'reference'"
    remove_column :dam_storage_locations, :ignore_patterns
    remove_column :dam_assets, :derivative_error
    remove_column :dam_assets, :derivative_state
    remove_column :dam_assets, :storage_kind
  end
end
