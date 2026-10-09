# frozen_string_literal: true

# One page of a CSV or spreadsheet preview. The presenter still owns parsing
# limits for callers that want a single capped window.
module WorkflowOutputPage
  private

  def load_csv_page
    headers = nil
    page_rows = []
    seen = 0
    CSV.foreach(path, encoding: 'bom|utf-8') do |record|
      if headers.nil?
        headers = record
        next
      end

      seen += 1
      page_rows << record if seen > page_offset && page_rows.size < page_limit
    end
    @row_count = seen
    @truncated = false
    assign_table(headers || [], page_rows)
  end

  def load_xlsx_page(sheet, headers, first_data_row)
    last_row = sheet.last_row.to_i
    @row_count = [last_row - first_data_row + 1, 0].max
    start_row = first_data_row + page_offset
    end_row = [start_row + page_limit - 1, last_row].min
    rows = start_row <= last_row ? (start_row..end_row).map { |row_number| sheet.row(row_number) } : []
    @truncated = false
    assign_table(headers, rows)
  end

  def paging?
    !@page.nil?
  end

  def page_limit
    @per_page || max_rows
  end

  def page_offset
    ([@page.to_i, 1].max - 1) * page_limit
  end
end
