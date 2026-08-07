# frozen_string_literal: true

# The registry of custom metadata fields an asset can carry.
#
# Advanced Search lets you "add more custom metadata filters"; this table is
# what populates that field picker. Without it the modal would have to offer a
# free-text key box, which only works if you already know what somebody typed
# when they ingested the file three years ago.
class CreateDamMetadataFields < ActiveRecord::Migration[8.0]
  def change
    create_table :dam_metadata_fields do |t|
      t.string :key, null: false
      t.string :label, null: false
      # text | number | date | select — drives both the input the modal renders
      # and which comparison operators it offers.
      t.string :field_type, null: false, default: 'text'
      t.text :options, comment: 'JSON array of choices when field_type is select'
      t.text :description
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :dam_metadata_fields, :key, unique: true
  end
end
