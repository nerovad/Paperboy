# frozen_string_literal: true

require 'csv'
require 'roo'

class WorkflowOutputPresenter
  include WorkflowOutputPage

  MAX_ROWS = 500
  MAX_TEXT_BYTES = 1_000_000
  # Above this size, page 1 does not parse the rest of the file for a count.
  EXACT_COUNT_MAX_BYTES = 32 * 1024 * 1024

  attr_reader :path, :kind, :headers, :rows, :content, :max_rows, :row_count

  def initialize(path, header_row: nil, spreadsheet: Roo::Spreadsheet, max_rows: MAX_ROWS,
                 page: nil, per_page: nil)
    @path = path
    @header_row = header_row
    @spreadsheet = spreadsheet
    @max_rows = max_rows
    @page = page
    @per_page = per_page
    @kind = path.extname.delete_prefix('.').downcase
    load_output
  end

  def self.exact_csv_count?(path)
    Pathname(path).size <= EXACT_COUNT_MAX_BYTES
  end

  def truncated?
    @truncated
  end

  def more?
    @more == true
  end

  def page_number
    [@page.to_i, 1].max
  end

  def page_from
    rows.empty? ? 0 : page_offset + 1
  end

  def page_to
    page_offset + rows.size
  end

  # Adapt file output to the PFA grid contract without moving file parsing or
  # preview limits into the framework.
  def grid_table
    Pfa::Grid::Table.new(
      columns: headers.each_with_index.map { |label, index| { key: index, label: label } },
      rows: rows
    )
  end

  private

  def exact_csv_count?
    self.class.exact_csv_count?(path)
  end

  def load_output
    case kind
    when 'csv' then load_csv
    when 'xlsx' then load_xlsx
    when 'sql' then load_sql
    else raise ArgumentError, "Unsupported output type: #{kind}"
    end
  end

  def load_csv
    return load_character_csv if BcpCharacterFile.applied_path?(path)
    return load_csv_page if paging?

    records = CSV.foreach(path, encoding: 'bom|utf-8').take(max_rows + 2)
    headers = records.shift || []
    @truncated = records.size > max_rows
    assign_table(headers, records.first(max_rows))
  end

  def load_xlsx
    workbook = @spreadsheet.open(path.to_s, extension: :xlsx)
    sheet = workbook.sheet(0)
    worksheet_header_row = @header_row ? @header_row + 1 : first_tabular_row(sheet)
    headers = worksheet_header_row ? sheet.row(worksheet_header_row) : []
    first_data_row = worksheet_header_row.to_i + 1
    if paging?
      load_xlsx_page(sheet, headers, first_data_row)
    else
      last_displayed_row = [sheet.last_row.to_i, first_data_row + max_rows - 1].min
      rows = last_displayed_row >= first_data_row ? (first_data_row..last_displayed_row).map { |row_number| sheet.row(row_number) } : []
      @truncated = sheet.last_row.to_i > last_displayed_row
      assign_table(headers, rows)
    end
  end

  def load_sql
    bytes = path.open('rb') { |file| file.read(MAX_TEXT_BYTES + 1) }
    @truncated = bytes.bytesize > MAX_TEXT_BYTES
    @content = bytes.byteslice(0, MAX_TEXT_BYTES).force_encoding('UTF-8').scrub
  end

  def first_tabular_row(sheet)
    (1..sheet.last_row.to_i).find { |row_number| sheet.row(row_number).compact_blank.size > 1 }
  end

  def assign_table(headers, rows)
    rows = rows.map { |row| Array(row) }
    width = ([Array(headers).size] + rows.map(&:size)).max.to_i
    @headers = normalize_headers(headers, width)
    @rows = rows.map { |row| row.first(width).fill(nil, row.size...width) }
  end

  def normalize_headers(headers, width)
    normalized = Array(headers).first(width).each_with_index.map do |header, index|
      header.presence || "Column #{index + 1}"
    end

    normalized.fill(nil, Array(headers).size...width).map.with_index do |header, index|
      header || "Column #{index + 1}"
    end
  end
end
