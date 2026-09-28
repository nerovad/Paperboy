# frozen_string_literal: true

# AIM's budget units (Joshua, 2026-09-28): the BUs AIM works with, chosen by an
# AIM Admin from the Chart of Accounts. One setting for every BU list -- Upload,
# Move, profiles, By BU. A row with no unit_id is a whole agency, so units the
# COA adds to it later are included. No database foreign keys and explicit
# index names: see test/lib/aim/schema_conventions_test.rb.
class CreateAimEnabledUnits < ActiveRecord::Migration[8.1]
  def change
    create_table 'aim.enabled_units' do |t|
      t.string :agency_id, limit: 10, null: false
      t.string :unit_id, limit: 10
      t.string :enabled_by, limit: 255
      t.timestamps
    end

    add_index 'aim.enabled_units', %i[agency_id unit_id], unique: true, name: 'index_aim_enabled_units_on_agency_and_unit'
  end
end
