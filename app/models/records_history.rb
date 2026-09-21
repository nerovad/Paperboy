# frozen_string_literal: true

# The change history of one Records table (see RegistryTable): every audited
# edit to its rows and, for tables that audit their lifecycle, every row added
# and deleted. Read by the per-row History modal and the table's change log.
#
# Entries are found by model rather than by RecordEdit#table_slug: a form
# model stamps its own edits with its table name, so a form-backed table's
# grid edits and form edits only meet under the model name.
#
# A table that narrows its rows (the OSHA 300 Log shows approved reports only)
# narrows its history the same way, so the change log never shows edits to a
# draft the grid would not. Deleted rows are kept, since their `destroy`
# entries are the only place they still exist.
class RecordsHistory
  attr_reader :table

  def initialize(table)
    @table = table
  end

  # RecordEdit rows for the table, unordered.
  def edits
    base = RecordEdit.where(record_type: table.model.name)
    base.where(record_id: table.scope.except(:includes).select(:id))
        .or(base.where(record_id: deleted_ids))
  end

  # Whether row `id` belongs to this table's history: a row the grid shows, or
  # one that was deleted from it.
  def row?(id)
    table.scope.exists?(id: id) || deleted_ids.exists?(record_id: id)
  end

  # One row's history, oldest save first.
  def row_entries(id)
    Forms::EditTrail.for_rows(table.model, edits.where(record_id: id))
  end

  # record_id => label, for the rows `entries` mention. Live rows are named from
  # the database; a deleted row is rebuilt from the values its `destroy` entries
  # kept, so it is still named the way it was.
  def row_labels(entries)
    ids = entries.map(&:record_id).uniq
    live = table.scope.except(:includes).where(id: ids).index_by(&:id)

    ids.index_with do |id|
      record = live[id] || deleted_stand_in(id)
      record ? table.row_label(record) : "##{id}"
    end
  end

  private

  def deleted_ids
    RecordEdit.where(record_type: table.model.name, action: 'destroy').select(:record_id)
  end

  def deleted_stand_in(id)
    values = RecordEdit.where(record_type: table.model.name, record_id: id, action: 'destroy')
                       .pluck(:column_name, :old_value).to_h
    return nil if values.empty?

    table.model.new(values.slice(*table.model.column_names).except(*encrypted_columns)).tap { |r| r.id = id }
  rescue StandardError
    nil
  end

  def encrypted_columns
    Array(table.model.try(:encrypted_attributes)).map(&:to_s)
  end
end
