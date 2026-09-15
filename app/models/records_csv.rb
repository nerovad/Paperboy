# frozen_string_literal: true

require 'csv'

# Writes a RecordsView as a CSV: one header row of column labels, then one row
# per record, in the view's order. Cells come from each column's raw extractor
# -- the same value the grid filters and sorts on -- formatted as plain text a
# spreadsheet reads, not the grid's HTML badges and dashes.
module RecordsCsv
  module_function

  # A cell starting with one of these is run as a formula by Excel and Sheets.
  # Record values are typed in by users, so they are defused rather than trusted.
  FORMULA_TRIGGERS = /\A[=+\-@\t\r]/

  def generate(view)
    columns = exportable_columns(view)

    CSV.generate do |csv|
      csv << columns.map(&:label)
      view.rows.each { |row| csv << columns.map { |column| cell(column, row) } }
    end
  end

  def filename(table, date = Date.current)
    "#{table.slug}-#{date.iso8601}.csv"
  end

  # Encrypted attributes are left out even when a table declares one as a
  # column: they decrypt on read, and a download is a copy nobody can revoke.
  def exportable_columns(view)
    view.columns.reject { |column| RecordsEditing.encrypted?(view.table.model, column.id) }
  end

  def cell(column, row)
    value = column.value&.call(row)

    case value
    when nil then ''
    when true then 'Yes'
    when false then 'No'
    when Numeric then value.is_a?(BigDecimal) ? value.to_s('F') : value.to_s
    when Date then value.iso8601
    when Time, DateTime, ActiveSupport::TimeWithZone
      value.in_time_zone(RecurringSchedule::TIME_ZONE).strftime('%Y-%m-%d %H:%M')
    else defuse(value.to_s)
    end
  end

  def defuse(text)
    text.match?(FORMULA_TRIGGERS) ? "'#{text}" : text
  end
end
