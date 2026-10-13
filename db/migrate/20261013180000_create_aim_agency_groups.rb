# frozen_string_literal: true

# Agency groups (#131): AIM's backbone for serving more than one agency. Each
# COA agency has its own group; an AIM Admin may make custom groups of an
# agency's BUs, which leaves those BUs out of the agency's group. Every BU is
# in exactly one group, so every invoice finds one. A group carries its own
# Fiscal people, Group Admins and Fiscal settings (export, hold reasons, tags,
# what must be filled in before archive), and may process other groups too.
#
# The Fiscal switch on aim.members becomes the fiscal role in the GSA group:
# GSA is the only agency working Fiscal in AIM today.
#
# No database foreign keys and explicit index names: see
# test/lib/aim/schema_conventions_test.rb.
class CreateAimAgencyGroups < ActiveRecord::Migration[8.1]
  def up
    create_groups
    create_units
    create_roles
    create_coverages
    move_fiscal_switch
    remove_column 'aim.members', :fiscal
  end

  def create_groups
    create_table 'aim.agency_groups' do |t|
      t.string :name, limit: 100, null: false
      t.string :agency_id, limit: 10, null: false
      t.boolean :custom, default: false, null: false
      t.string :export_format, limit: 10, default: 'csv', null: false
      t.text :export_columns
      t.text :hold_reasons
      t.text :tag_suggestions
      t.string :required_fields, limit: 500
      t.string :updated_by, limit: 255
      t.timestamps
    end
    add_index 'aim.agency_groups', :name, unique: true, name: 'index_aim_agency_groups_on_name'
    add_index 'aim.agency_groups', %i[agency_id custom], name: 'index_aim_agency_groups_on_agency_and_custom'
  end

  def create_units
    create_table 'aim.agency_group_units' do |t|
      t.bigint :agency_group_id, null: false
      t.string :agency_id, limit: 10, null: false
      t.string :budget_unit, limit: 10, null: false
      t.string :added_by, limit: 255
      t.timestamps
    end
    add_index 'aim.agency_group_units', %i[agency_id budget_unit], unique: true,
                                                                   name: 'index_aim_agency_group_units_on_agency_and_unit'
    add_index 'aim.agency_group_units', :agency_group_id, name: 'index_aim_agency_group_units_on_group'
  end

  def create_roles
    create_table 'aim.agency_group_roles' do |t|
      t.bigint :agency_group_id, null: false
      t.integer :employee_id, null: false
      t.string :role, limit: 20, null: false
      t.string :granted_by, limit: 255
      t.timestamps
    end
    add_index 'aim.agency_group_roles', %i[agency_group_id employee_id role], unique: true,
                                                                              name: 'index_aim_agency_group_roles_on_group_person_role'
    add_index 'aim.agency_group_roles', :employee_id, name: 'index_aim_agency_group_roles_on_employee'
  end

  # Fiscal also processes (Joshua, 2026-10-13): a group's Fiscal people and
  # Group Admins also work the groups it covers.
  def create_coverages
    create_table 'aim.agency_group_coverages' do |t|
      t.bigint :agency_group_id, null: false
      t.bigint :covered_group_id, null: false
      t.string :added_by, limit: 255
      t.timestamps
    end
    add_index 'aim.agency_group_coverages', %i[agency_group_id covered_group_id], unique: true,
                                                                                  name: 'index_aim_agency_group_coverages_on_pair'
    add_index 'aim.agency_group_coverages', :covered_group_id, name: 'index_aim_agency_group_coverages_on_covered'
  end

  def move_fiscal_switch
    execute <<~SQL.squish
      INSERT INTO aim.agency_groups (name, agency_id, custom, export_format, created_at, updated_at)
      VALUES ('GSA · General Services Agency', 'GSA', 0, 'csv', SYSDATETIME(), SYSDATETIME())
    SQL
    execute <<~SQL.squish
      INSERT INTO aim.agency_group_roles (agency_group_id, employee_id, role, granted_by, created_at, updated_at)
      SELECT g.id, m.employee_id, 'fiscal', 'the Fiscal switch, moved by #131', SYSDATETIME(), SYSDATETIME()
      FROM aim.members m CROSS JOIN aim.agency_groups g
      WHERE m.fiscal = 1 AND g.agency_id = 'GSA' AND g.custom = 0
    SQL
  end

  def down
    add_column 'aim.members', :fiscal, :boolean, default: false, null: false
    execute <<~SQL.squish
      UPDATE m SET fiscal = 1 FROM aim.members m
      WHERE EXISTS (SELECT 1 FROM aim.agency_group_roles r WHERE r.employee_id = m.employee_id AND r.role = 'fiscal')
    SQL
    drop_table 'aim.agency_group_coverages'
    drop_table 'aim.agency_group_roles'
    drop_table 'aim.agency_group_units'
    drop_table 'aim.agency_groups'
  end
end
