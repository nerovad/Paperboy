# frozen_string_literal: true

# Conditional row colouring for a Records table, set up from the grid by the
# table's editors and seen by everyone who opens it (see RecordsHighlightRule).
class CreateRecordsHighlightRules < ActiveRecord::Migration[8.1]
  def change
    create_table :records_highlight_rules do |t|
      t.string :table_slug, null: false
      t.string :column_name, null: false
      t.string :operator, null: false
      t.string :value
      t.string :color, null: false
      t.string :label
      t.integer :position, null: false, default: 0
      t.integer :created_by_employee_id
      t.timestamps
    end
    add_index :records_highlight_rules, %i[table_slug position]
  end
end
