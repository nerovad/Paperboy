# frozen_string_literal: true

# AIM v2: vendor aliases are a table, not a JSON file three programs wrote to.
# One row per spelling the AI has read, naming the official vendor it means.
# No database foreign keys and explicit index names: see
# test/lib/aim/schema_conventions_test.rb.
class CreateAimVendorAliases < ActiveRecord::Migration[8.1]
  def change
    create_table 'aim.vendor_aliases' do |t|
      t.string :extracted_name, limit: 255, null: false
      t.string :normalized_name, limit: 255, null: false
      t.string :learned_by, limit: 255
      t.string :note, limit: 500
      t.timestamps
    end

    add_index 'aim.vendor_aliases', :extracted_name, unique: true, name: 'index_aim_vendor_aliases_on_extracted_name'
    add_index 'aim.vendor_aliases', :normalized_name, name: 'index_aim_vendor_aliases_on_normalized_name'
  end
end
