# frozen_string_literal: true

# Stamp layouts (#221): what an agency group's approval stamp says and where
# each stamp area sits. Every save is a new row, never an update, so the rows
# are the layout's history: who changed it, when, and to what. The newest row
# for a group is its layout; agency_group_id NULL is the default for groups
# with none. A Fiscal record names the layout that stamped its PDF
# (stamp_layout_id), and keeps any safety-net warnings (stamp_warnings).
#
# Explicit index names: see test/lib/aim/schema_conventions_test.rb. A second
# run, or a run after a crash, adds only what is missing.
class CreateAimStampLayouts < ActiveRecord::Migration[8.1]
  def up
    unless table_exists?('aim.stamp_layouts')
      create_table 'aim.stamp_layouts' do |t|
        t.bigint :agency_group_id
        t.text :areas, null: false
        t.string :note, limit: 500
        t.string :created_by, limit: 255, null: false
        t.datetime :created_at, null: false
      end
    end
    add_index 'aim.stamp_layouts', %i[agency_group_id id], name: 'index_aim_stamp_layouts_on_group_and_id',
                                                           if_not_exists: true
    add_column 'aim.fiscal_records', :stamp_layout_id, :bigint unless column_exists?('aim.fiscal_records', :stamp_layout_id)
    return if column_exists?('aim.fiscal_records', :stamp_warnings)

    add_column 'aim.fiscal_records', :stamp_warnings, :string, limit: 500
  end

  def down
    remove_column 'aim.fiscal_records', :stamp_warnings if column_exists?('aim.fiscal_records', :stamp_warnings)
    remove_column 'aim.fiscal_records', :stamp_layout_id if column_exists?('aim.fiscal_records', :stamp_layout_id)
    drop_table 'aim.stamp_layouts' if table_exists?('aim.stamp_layouts')
  end
end
