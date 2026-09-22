# frozen_string_literal: true

# Governance over which assets a person sees and what they may do with them.
#
# A rule names a slice of the library (an org window on the asset and any
# number of metadata conditions) and the people it is open to. Once any rule
# matches an asset, only those people see it; the flags say what else they
# may do beyond looking. See Dam::AccessRule.
class CreateDamAccessRules < ActiveRecord::Migration[8.1]
  def change
    create_table :dam_access_rules do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :active, null: false, default: true
      t.string :agency_id
      t.string :division_id
      t.string :department_id
      t.string :unit_id
      t.text :conditions
      t.boolean :can_download, null: false, default: false
      t.boolean :can_share, null: false, default: false
      t.boolean :can_publish, null: false, default: false
      t.boolean :can_edit, null: false, default: false
      t.string :created_by_id
      t.string :created_by_name
      t.timestamps
    end
    add_index :dam_access_rules, :active

    create_table :dam_access_rule_grantees do |t|
      t.bigint :rule_id, null: false
      t.string :grantee_type, null: false
      t.integer :group_id
      t.string :employee_id
      t.string :agency_id
      t.string :division_id
      t.string :department_id
      t.string :unit_id
      t.datetime :created_at, null: false
    end
    add_index :dam_access_rule_grantees, :rule_id
    add_index :dam_access_rule_grantees, %i[grantee_type group_id]
    add_index :dam_access_rule_grantees, %i[grantee_type employee_id]
  end
end
