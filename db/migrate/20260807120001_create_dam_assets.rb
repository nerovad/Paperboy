# frozen_string_literal: true

# The core DAM record: one managed file plus the metadata we search it by.
#
# The bytes themselves ride on Active Storage (has_one_attached :file), so the
# columns here are the *searchable* projection of the file — the things
# Advanced Search filters on and the grid renders without touching storage.
# Technical metadata (dimensions, duration) is denormalised for the same
# reason: a media grid must not open 200 files to draw one page.
class CreateDamAssets < ActiveRecord::Migration[8.0]
  def change
    create_table :dam_assets do |t|
      t.string :title, null: false
      t.text :description
      t.string :filename

      # image | video | document | audio | other. Coarse enough to be a useful
      # facet; `format` below carries the specific one (PNG, JPG, MP4).
      t.string :media_type, null: false, default: 'other'
      t.string :format
      t.string :content_type

      t.bigint :byte_size
      t.string :checksum

      t.references :storage_location, foreign_key: { to_table: :dam_storage_locations }
      t.string :storage_path

      t.integer :width
      t.integer :height
      t.integer :duration_seconds

      # Employee id + a name snapshot, matching how the rest of Paperboy stores
      # actors: the id resolves against GSABSS, the name still renders if the
      # employee later leaves.
      t.string :uploaded_by_id
      t.string :uploaded_by_name

      # active | processing | failed | archived
      t.string :status, null: false, default: 'active'
      t.datetime :ingested_at

      t.timestamps
    end

    add_index :dam_assets, :media_type
    add_index :dam_assets, :format
    add_index :dam_assets, :uploaded_by_id
    add_index :dam_assets, :status
    add_index :dam_assets, :created_at
  end
end
