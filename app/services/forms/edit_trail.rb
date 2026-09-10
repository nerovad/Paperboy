# frozen_string_literal: true

# app/services/forms/edit_trail.rb

module Forms
  # A record's edit history, shaped for display: one entry per save rather than
  # one per column.
  #
  # RecordEdit deliberately stores a row per column, because that is the unit a
  # subscription digest and the Records grid both want. A person reading the
  # history wants the save, "Jane changed 3 fields at 9:14", so the rows are
  # regrouped here. They are stamped a row at a time (RecordEdit.capture sets
  # its own created_at), so a save's rows can land microseconds apart; rows by
  # the same actor inside GROUPING_WINDOW are treated as one save.
  class EditTrail
    GROUPING_WINDOW = 5

    Change = Struct.new(:column, :label, :old_value, :new_value, keyword_init: true)
    Entry = Struct.new(:at, :actor_name, :actor_id, :changes, keyword_init: true)

    # Oldest save first, so an edit trail rendered next to a status timeline
    # reads in the same direction as it.
    def self.for(record)
      new(record).entries
    end

    def initialize(record)
      @record = record
      @values = Forms::AuditValue.new(model: record.class)
    end

    def entries
      group(@record.edit_timeline.to_a.sort_by(&:created_at))
    end

    private

    def group(rows)
      rows.each_with_object([]) do |row, entries|
        if same_save?(entries.last, row)
          entries.last.changes << change_for(row)
        else
          entries << Entry.new(at: row.created_at, actor_name: row.changed_by_name,
                               actor_id: row.changed_by_id, changes: [change_for(row)])
        end
      end
    end

    def same_save?(entry, row)
      return false unless entry
      return false unless entry.actor_id.to_s == row.changed_by_id.to_s

      (row.created_at - entry.at).abs < GROUPING_WINDOW
    end

    def change_for(row)
      Change.new(
        column: row.column_name,
        label: label_for(row.column_name),
        old_value: @values.call(row.column_name, row.old_value),
        new_value: @values.call(row.column_name, row.new_value)
      )
    end

    # The form's own label for the column where it has one, so the trail names a
    # field the way the form that collects it does; its humanized column name
    # otherwise.
    def label_for(column)
      form_field_labels[column].presence || column.humanize
    end

    def form_field_labels
      @form_field_labels ||= Forms::FieldLabels.for(@record.class)
    end
  end
end
