# frozen_string_literal: true

# Audit trail for inline Records-grid edits. The grid rewrites stored values in
# place, so without this the previous value is gone the moment the review modal
# closes — status_changes only tracks status transitions, not field values.
# One row per column changed, so a batch save writes several.
class CreateRecordEdits < ActiveRecord::Migration[8.0]
  def change
    create_table :record_edits do |t|
      t.string :record_type, null: false
      t.bigint :record_id, null: false
      t.string :table_slug, null: false
      t.string :column_name, null: false
      t.text :old_value
      t.text :new_value
      t.string :changed_by_id
      t.string :changed_by_name
      t.datetime :created_at, null: false
    end

    add_index :record_edits, %i[record_type record_id]
    add_index :record_edits, :created_at
  end
end
