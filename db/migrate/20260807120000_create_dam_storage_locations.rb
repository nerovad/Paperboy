# frozen_string_literal: true

# Where an asset's bytes actually live. A DAM outlives any one storage backend
# — files start on a share, move to object storage, and old masters land on
# cheap cold storage — so "storage" is a first-class filter in Advanced Search
# rather than something inferred from a path prefix.
class CreateDamStorageLocations < ActiveRecord::Migration[8.0]
  def change
    create_table :dam_storage_locations do |t|
      t.string :key, null: false
      t.string :label, null: false
      # disk | s3 | smb | archive — how the adapter reaches it, not where it is.
      t.string :kind, null: false, default: 'disk'
      t.string :root, comment: 'Filesystem root, bucket name or UNC share'
      t.text :description
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :dam_storage_locations, :key, unique: true
  end
end
