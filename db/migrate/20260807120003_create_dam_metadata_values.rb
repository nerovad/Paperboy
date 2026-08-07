# frozen_string_literal: true

# One custom metadata value on one asset — the EAV side of the field registry
# in dam_metadata_fields.
#
# `value` is a bounded string rather than text on purpose: SQL Server cannot
# index varchar(max), and the entire reason this table exists is to be filtered
# on. Anything longer than a searchable value belongs in the asset description.
class CreateDamMetadataValues < ActiveRecord::Migration[8.0]
  def change
    create_table :dam_metadata_values do |t|
      t.references :asset, null: false, foreign_key: { to_table: :dam_assets }
      t.string :field_key, null: false
      t.string :value, limit: 450
      # Parallel typed columns so range filters ("shot after 2024", "rating over
      # 3") compare numbers and dates rather than their string spellings.
      t.decimal :numeric_value, precision: 18, scale: 4
      t.datetime :date_value
      t.timestamps
    end

    add_index :dam_metadata_values, %i[field_key value]
    add_index :dam_metadata_values, %i[asset_id field_key], unique: true
  end
end
