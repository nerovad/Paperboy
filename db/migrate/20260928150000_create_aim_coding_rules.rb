# frozen_string_literal: true

# The coding lookups (item b, 2026-09-28): Fiscal's yearly CSVs as rows. A
# rule says what a vendor's invoices in a budget unit are coded with; every
# import is a batch that can be undone as one; every change to a rule is
# kept. No database foreign keys and explicit index names: see
# test/lib/aim/schema_conventions_test.rb.
class CreateAimCodingRules < ActiveRecord::Migration[8.1]
  def change
    create_imports
    create_rules
    create_changes
  end

  private

  def create_imports
    create_table 'aim.coding_imports' do |t|
      t.string :agency, limit: 3, null: false
      t.string :file_name, limit: 260, null: false
      t.string :imported_by, limit: 255, null: false
      t.string :effective_option, limit: 20, null: false
      t.date :effective_from
      t.integer :row_count, null: false, default: 0
      t.integer :loaded_count, null: false, default: 0
      t.integer :refused_count, null: false, default: 0
      t.integer :retired_count, null: false, default: 0
      t.text :report
      t.datetime :undone_at
      t.string :undone_by, limit: 255
      t.timestamps
    end
  end

  def create_rules
    create_table 'aim.coding_rules' do |t|
      t.string :agency, limit: 3, null: false
      t.string :budget_unit, limit: 10, null: false
      t.string :vendor_name, limit: 255, null: false
      t.string :vendor_key, limit: 255, null: false
      t.string :customer_number, limit: 100
      t.string :encumbrance_type, limit: 10
      t.string :encumbrance_number, limit: 100
      t.string :ma_number, limit: 100
      t.string :vendor_code, limit: 50
      t.string :fund, limit: 20
      t.string :department, limit: 20
      t.string :object_code, limit: 20
      t.string :dept_object, limit: 20
      t.string :activity, limit: 20
      t.string :function_code, limit: 20
      t.string :major_program, limit: 20
      t.string :program, limit: 20
      t.string :phase, limit: 20
      t.string :task, limit: 20
      t.text :notes
      t.date :effective_from, null: false
      t.date :effective_until
      t.bigint :import_id
      t.integer :source_row
      t.bigint :retired_by_import_id
      t.string :created_by, limit: 255
      t.string :updated_by, limit: 255
      t.timestamps
    end
    add_index 'aim.coding_rules', %i[agency budget_unit vendor_key], name: 'index_aim_coding_rules_on_agency_unit_vendor'
    add_index 'aim.coding_rules', :vendor_key, name: 'index_aim_coding_rules_on_vendor_key'
    add_index 'aim.coding_rules', :import_id, name: 'index_aim_coding_rules_on_import_id'
    add_index 'aim.coding_rules', :retired_by_import_id, name: 'index_aim_coding_rules_on_retired_by_import_id'
  end

  def create_changes
    create_table 'aim.coding_rule_changes' do |t|
      t.bigint :coding_rule_id, null: false
      t.string :kind, limit: 20, null: false
      t.string :field, limit: 40
      t.text :before
      t.text :after
      t.string :changed_by, limit: 255, null: false
      t.datetime :created_at, null: false
    end
    add_index 'aim.coding_rule_changes', %i[coding_rule_id created_at], name: 'index_aim_coding_rule_changes_on_rule_and_time'
  end
end
