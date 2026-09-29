# frozen_string_literal: true

module Aim
  # What a lookup file would do, row by row (item b.3): the counts, every row
  # with its outcome and the values read, the refusals and why.
  module LookupReport
    module_function

    SHOWN = %w[vendor_name customer_number budget_unit encumbrance ma_number vendor_code fund object_code activity
               function_code program notes].freeze

    def build(import)
      kinds = import.outcomes.map { |o| [o, import.outcome_kind(o)] }
      { file: import.file_name, agency: import.agency, rows: import.outcomes.size, loadable: import.loadable.size, refused: import.refused.size,
        adds: kinds.count { |_, k| k == 'add' }, edits: kinds.count { |_, k| k == 'edit' },
        unchanged: kinds.count { |_, k| k == 'unchanged' },
        all_rows: kinds.map do |o, kind|
          { row: o.row.number, kind: kind, acceptable: o.acceptable?, reasons: o.reasons + o.objections, notes: o.notes,
            values: SHOWN.to_h { |f| [f, o.rule.public_send(f)] } }
        end,
        unknown_columns: import.unknown_columns,
        refused_rows: import.refused.map do |o|
          { row: o.row.number, vendor: o.row.fields['vendor_name'], reasons: o.reasons + o.objections, acceptable: o.acceptable? }
        end,
        accepted_rows: import.loadable.select(&:accepted).map { |o| { row: o.row.number, warnings: o.objections } },
        noted_rows: import.loadable.select { |o| o.notes.any? }.map { |o| { row: o.row.number, notes: o.notes } } }
    end

    # import: a previewed Aim::CodingImport to apply into; else a new row.
  end
end
