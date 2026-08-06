# frozen_string_literal: true

require 'axlsx'
require 'prawn'
require 'prawn/table'

module Billing
  class ReportGenerator
    NAMES_PROCEDURE = 'GSABSS.dbo.Export_TC60_Billing_Report_Names'
    DATA_PROCEDURE = 'GSABSS.dbo.Export_TC60_To_Billing_File'
    VERSION = '01'
    PDF_ROWS_PER_PAGE = 29

    def initialize(report)
      @report = report
    end

    def call
      definitions.map { |definition| build_artifact(definition) }
    end

    private

    attr_reader :report

    def definitions
      sql = <<~SQL.squish
        EXEC #{NAMES_PROCEDURE} @sDate = ?, @eDate = ?, @version = ?
      SQL
      query(sql, report.start_date, report.end_date, VERSION).map do |row|
        row.transform_keys(&:downcase)
      end
    end

    def build_artifact(definition)
      result = report_data(definition)
      ReportArtifact.new(
        name: definition.fetch('name'),
        pdf_name: definition.fetch('pdffile'),
        pdf_data: build_pdf(definition, result),
        xlsx_name: definition.fetch('xlsfile'),
        xlsx_data: build_xlsx(definition, result)
      )
    end

    def report_data(definition)
      sql = <<~SQL.squish
        EXEC #{DATA_PROCEDURE}
          @sDate = ?, @eDate = ?, @type = ?, @digits = ?, @encumbered = ?
      SQL
      query(
        sql, report.start_date, report.end_date, definition.fetch('tc60'),
        definition.fetch('digit'), definition.fetch('encumbered')
      )
    end

    def build_xlsx(definition, result)
      package = Axlsx::Package.new
      package.workbook.add_worksheet(name: 'Data') do |sheet|
        header = sheet.styles.add_style(b: true, bg_color: '64748B', fg_color: 'FFFFFF')
        sheet.add_row(result.columns, style: header)
        result.rows.each { |row| sheet.add_row(row) }
        if result.columns.any?
          last_column = Axlsx.col_ref(result.columns.length - 1)
          sheet.auto_filter = "A1:#{last_column}#{result.rows.length + 1}"
        end
      end
      package.workbook.add_worksheet(name: 'Summary') do |sheet|
        sheet.add_row ['Report', definition.fetch('name')]
        sheet.add_row ['Start Date', report.start_date]
        sheet.add_row ['End Date', report.end_date]
        sheet.add_row ['Rows', result.rows.length]
      end
      package.to_stream.read
    end

    def build_pdf(definition, result)
      Prawn::Document.new(page_layout: :landscape, page_size: 'A3', margin: 24) do |pdf|
        pdf_pages(pdf, definition, result)
      end.render
    end

    def pdf_pages(pdf, definition, result)
      batches = result.rows.each_slice(PDF_ROWS_PER_PAGE).to_a
      batches = [[]] if batches.empty?

      batches.each_with_index do |rows, index|
        pdf.start_new_page unless index.zero?
        pdf_header(pdf, definition)
        pdf_table(pdf, result.columns, rows)
      end
    end

    def pdf_header(pdf, definition)
      pdf.text definition.fetch('name'), size: 14, style: :bold
      pdf.text "#{report.start_date} through #{report.end_date}", size: 8
      pdf.move_down 8
    end

    def pdf_table(pdf, columns, rows)
      return if columns.empty?

      widths = Array.new(columns.length, pdf.bounds.width / columns.length)
      pdf.table([columns] + rows.map { |row| row.map(&:to_s) },
                column_widths: widths, cell_style: { size: 4, padding: 2, overflow: :shrink_to_fit }) do
        row(0).font_style = :bold
        row(0).background_color = '64748B'
        row(0).text_color = 'FFFFFF'
      end
    end

    def query(sql, *values)
      sanitized = ActiveRecord::Base.send(:sanitize_sql_array, [sql, *values])
      BillingBase.connection.exec_query(sanitized)
    end
  end
end
