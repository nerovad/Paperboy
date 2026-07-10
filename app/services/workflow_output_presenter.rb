# frozen_string_literal: true

require "csv"
require "roo"

class WorkflowOutputPresenter
  MAX_ROWS = 500
  MAX_TEXT_BYTES = 1_000_000

  attr_reader :path, :kind, :headers, :rows, :content

  def initialize(path, header_row: nil, spreadsheet: Roo::Spreadsheet)
    @path = path
    @header_row = header_row
    @spreadsheet = spreadsheet
    @kind = path.extname.delete_prefix(".").downcase
    load_output
  end

  def truncated?
    @truncated
  end

  private

  def load_output
    case kind
    when "csv" then load_csv
    when "xlsx" then load_xlsx
    when "sql" then load_sql
    else raise ArgumentError, "Unsupported output type: #{kind}"
    end
  end

  def load_csv
    records = CSV.foreach(path, encoding: "bom|utf-8").take(MAX_ROWS + 2)
    @headers = records.shift || []
    @truncated = records.size > MAX_ROWS
    @rows = records.first(MAX_ROWS)
  end

  def load_xlsx
    workbook = @spreadsheet.open(path.to_s, extension: :xlsx)
    sheet = workbook.sheet(0)
    worksheet_header_row = @header_row ? @header_row + 1 : first_tabular_row(sheet)
    @headers = worksheet_header_row ? sheet.row(worksheet_header_row) : []
    first_data_row = worksheet_header_row.to_i + 1
    last_displayed_row = [ sheet.last_row.to_i, first_data_row + MAX_ROWS - 1 ].min
    @rows = last_displayed_row >= first_data_row ? (first_data_row..last_displayed_row).map { |row_number| sheet.row(row_number) } : []
    @truncated = sheet.last_row.to_i > last_displayed_row
  end

  def load_sql
    bytes = path.open("rb") { |file| file.read(MAX_TEXT_BYTES + 1) }
    @truncated = bytes.bytesize > MAX_TEXT_BYTES
    @content = bytes.byteslice(0, MAX_TEXT_BYTES).force_encoding("UTF-8").scrub
  end

  def first_tabular_row(sheet)
    (1..sheet.last_row.to_i).find { |row_number| sheet.row(row_number).compact_blank.size > 1 }
  end
end
