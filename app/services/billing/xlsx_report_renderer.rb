# frozen_string_literal: true

require 'axlsx'
require 'bigdecimal'

module Billing
  class XlsxReportRenderer
    BILLING_LABEL_INDEX = 27
    DECIMAL_COLUMN_INDEXES = [7, 23, 24, 25].freeze
    TEXT_COLUMNS = %w[DOC_NMBR DOC_NUBR DOC_NUMBR CUNIT COBJECT CACTIVTY
                      CFUNCTION CPROGRAM CPHASE SPHASE STASK].freeze
    COST_COLUMN_INDEX = 25
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
        sheet.add_row(header_values, style: header_styles(styles))
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
        count: sheet.styles.add_style(num_fmt: 3),
        decimal: sheet.styles.add_style(num_fmt: 2)
      }
    end

    def header_values
      pad_to_summary(result.columns) + ['Billing Amount', billing_amount]
    end

    def header_styles(styles)
      values = result.columns.each_index.map { |index| styles[:headers][index] }
      pad_to_summary(values).push(styles[:label], styles[:currency])
    end

    def add_data_rows(sheet, styles)
      rows = result.rows.presence || [[]]
      rows.each_with_index do |row, index|
        values = row
        row_styles = data_styles(styles)
        next sheet.add_row(values, style: row_styles, types: data_types) unless index.zero?

        values = pad_to_summary(values) + ['Number of Lines', result.rows.length]
        row_styles = pad_to_summary(row_styles) + [styles[:label], styles[:count]]
        sheet.add_row(values, style: row_styles, types: pad_to_summary(data_types))
      end
    end

    def data_types
      result.columns.map do |column|
        :string if TEXT_COLUMNS.include?(column.to_s.upcase)
      end
    end

    def data_styles(styles)
      Array.new(result.columns.length).tap do |values|
        DECIMAL_COLUMN_INDEXES.each do |index|
          values[index] = styles[:decimal] if index < values.length
        end
      end
    end

    def billing_amount
      result.rows.sum(BigDecimal('0')) do |row|
        BigDecimal(row.fetch(COST_COLUMN_INDEX, 0).to_s)
      rescue ArgumentError
        BigDecimal('0')
      end
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
