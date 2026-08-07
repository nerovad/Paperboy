# frozen_string_literal: true

# A named, ordered grouping of assets — the DAM equivalent of an album or a
# project folder. Collections nest via parent_id so a campaign can hold shoots
# which hold selects.
class CreateDamCollections < ActiveRecord::Migration[8.0]
  def change
    create_table :dam_collections do |t|
      t.string :name, null: false
      t.text :description
      t.references :parent, foreign_key: { to_table: :dam_collections }
      t.string :created_by_id
      t.string :created_by_name
      t.timestamps
    end

    add_index :dam_collections, :name

    create_table :dam_collection_assets do |t|
      t.references :collection, null: false, foreign_key: { to_table: :dam_collections }
      t.references :asset, null: false, foreign_key: { to_table: :dam_assets }
      # Curated order — a collection is a sequence, not a set.
      t.integer :position, null: false, default: 0
      t.string :added_by_id
      t.datetime :created_at, null: false
    end

    add_index :dam_collection_assets, %i[collection_id asset_id], unique: true
  end
end
