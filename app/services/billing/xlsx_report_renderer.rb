# frozen_string_literal: true

require 'axlsx'

module Billing
  class XlsxReportRenderer
    BILLING_LABEL_INDEX = 27
    HEADER_COLORS = {
      (0..6) => '95DCF7',
      (7..7) => 'D9F2D0',
      (8..14) => 'F1CEEE',
      (15..17) => 'B3E5A1',
      (18..22) => 'F6C6AD',
      (23..25) => 'E49EDD'
    }.freeze

    def initialize(report, definition, result)
      @report = report
      @definition = definition
      @result = result
    end

    def call
      package = Axlsx::Package.new
      add_data_sheet(package.workbook)
      add_summary_sheet(package.workbook)
      package.to_stream.read
    end

    private

    attr_reader :report, :definition, :result

    def add_data_sheet(workbook)
      workbook.add_worksheet(name: 'Data') do |sheet|
        styles = build_styles(sheet)
        header = sheet.add_row(header_values, style: header_styles(styles))
        header.cells.last.escape_formulas = false
        add_data_rows(sheet, styles)
        add_filter(sheet)
      end
    end

    def build_styles(sheet)
      headers = HEADER_COLORS.each_with_object({}) do |(range, color), styles|
        style = sheet.styles.add_style(b: true, bg_color: color, fg_color: '000000')
        range.each { |index| styles[index] = style }
      end
      {
        headers: headers,
        label: sheet.styles.add_style(b: true),
        currency: sheet.styles.add_style(num_fmt: 4),
        count: sheet.styles.add_style(num_fmt: 3)
      }
    end

    def header_values
      pad_to_summary(result.columns) + ['Billing Amount', billing_amount_formula]
    end

    def header_styles(styles)
      values = result.columns.each_index.map { |index| styles[:headers][index] }
      pad_to_summary(values).push(styles[:label], styles[:currency])
    end

    def add_data_rows(sheet, styles)
      rows = result.rows.presence || [[]]
      rows.each_with_index do |row, index|
        values = row
        row_styles = []
        next sheet.add_row(values) unless index.zero?

        values = pad_to_summary(values) + ['Number of Lines', '=COUNTA(A:A)-1']
        row_styles = pad_to_summary(row_styles) + [styles[:label], styles[:count]]
        summary_row = sheet.add_row(values, style: row_styles)
        summary_row.cells.last.escape_formulas = false
      end
    end

    def billing_amount_formula
      cost_index = result.columns.index { |column| column.to_s.casecmp('cost').zero? }
      raise ArgumentError, 'Billing report is missing the COST column' unless cost_index

      column = Axlsx.col_ref(cost_index)
      "=SUM(#{column}:#{column})"
    end

    def pad_to_summary(values)
      values + Array.new([BILLING_LABEL_INDEX - values.length, 0].max)
    end

    def add_filter(sheet)
      return if result.columns.empty?

      last_column = Axlsx.col_ref(result.columns.length - 1)
      sheet.auto_filter = "A1:#{last_column}#{result.rows.length + 1}"
    end

    def add_summary_sheet(workbook)
      workbook.add_worksheet(name: 'Summary') do |sheet|
        sheet.add_row ['Report', definition.fetch('name')]
        sheet.add_row ['Start Date', report.start_date]
        sheet.add_row ['End Date', report.end_date]
        sheet.add_row ['Rows', result.rows.length]
      end
    end
  end
end
