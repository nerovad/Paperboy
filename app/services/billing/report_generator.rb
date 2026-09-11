# frozen_string_literal: true

module Billing
  class ReportGenerator
    NAMES_PROCEDURE = 'GSABSS.dbo.Export_TC60_Billing_Report_Names'
    DATA_PROCEDURE = 'GSABSS.dbo.Export_TC60_To_Billing_File'
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
      query(sql, report.start_date, report.end_date, formatted_version).map do |row|
        row.transform_keys(&:downcase)
      end
    end

    def build_artifact(definition)
      result = report_data(definition)
      ReportArtifact.new(
        name: definition.fetch('name'),
        pdf_name: definition.fetch('pdffile'),
        pdf_data: build_pdf(definition, result),
        overlay_pdf_name: overlay_pdf_name(definition.fetch('pdffile')),
        overlay_pdf_data: build_overlay_pdf(definition, result),
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
      XlsxReportRenderer.new(report, definition, result).call
    end

    def build_pdf(definition, result)
      PdfReportRenderer.new(report, definition, result).call
    end

    def build_overlay_pdf(definition, result)
      PdfReportRenderer.new(report, definition, result, overlay: true).call
    end

    def overlay_pdf_name(pdf_name)
      basename = File.basename(pdf_name)
      stem = basename.delete_suffix(File.extname(basename))
      stem = stem.sub(/-v(?=\d+\z)/, '-overlay-v')
      stem = "#{stem}-overlay" unless stem.include?('-overlay')
      "#{stem}#{File.extname(basename)}"
    end

    def query(sql, *values)
      sanitized = ActiveRecord::Base.send(:sanitize_sql_array, [sql, *values])
      BillingBase.connection.exec_query(sanitized)
    end

    def formatted_version
      format('%02d', report.version)
    end
  end
end
