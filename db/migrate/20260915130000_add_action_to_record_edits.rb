# frozen_string_literal: true

class AddActionToRecordEdits < ActiveRecord::Migration[8.1]
  def change
    # What happened to the row: a column edited (the only thing recorded until
    # now, hence the default), or the whole row added or deleted. Added and
    # deleted rows write one entry per column, carrying the row's values, so a
    # row's history reads from its first version to its last.
    add_column :record_edits, :action, :string, limit: 10, null: false, default: 'update'

    # A Records table's change log reads one model's rows newest first.
    add_index :record_edits, %i[record_type created_at]
  end
end
