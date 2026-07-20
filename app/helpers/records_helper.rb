# frozen_string_literal: true

# View helpers for the Records grid (shared by the generic grid and the P-Card
# screen). Editability rules live in RecordsEditing; these just adapt them and
# the raw cell value for the inline-edit inputs.
module RecordsHelper
  def records_cell_editable?(table, column)
    RecordsEditing.editable?(table, column.id, column.kind)
  end

  # Raw value to seed an inline-edit input — dates as ISO (yyyy-mm-dd) so a
  # native date input accepts them; everything else as its plain value.
  def records_edit_raw(column, row)
    value = column.value&.call(row)
    return value.to_date.iso8601 if value.is_a?(Date) || value.is_a?(Time)

    value
  end
end
