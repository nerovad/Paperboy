# frozen_string_literal: true

# AIM v2: vendor-specific extraction rules -- plain-English hints the vision
# prompt is given for a known vendor -- as a table instead of vendor_rules.json.
class CreateAimVendorRules < ActiveRecord::Migration[8.1]
  def change
    create_table 'aim.vendor_rules' do |t|
      t.string :vendor_name, limit: 255, null: false
      t.text :rules, null: false
      t.string :updated_by, limit: 255
      t.timestamps
    end

    add_index 'aim.vendor_rules', :vendor_name, unique: true, name: 'index_aim_vendor_rules_on_vendor_name'
  end
end
