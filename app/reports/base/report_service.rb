# app/reports/base/report_service.rb
module Reports
  module Base
    class ReportService
      attr_reader :params

      def initialize(params)
        @params = params.symbolize_keys
      end

      # Main pipeline: SQL → YAML → Prawn
      def call
        data     = SqlProvider.new(stored_proc, params).fetch
        mapping  = YamlLoader.new(report_name).mapping
        template = TemplateLoader.new(report_name).path

        PdfRenderer.new(
          template: template,
          mapping:  mapping,
          data:     data,
          report:   report_name
        ).render
      end

      # ----------------------------------------------------------------------
      # Required overrides in child classes
      # ----------------------------------------------------------------------

      # Example: "dbo.Export_TC60_To_Billing_File"
      def stored_proc
        raise NotImplementedError, "#{self.class} must implement #stored_proc"
      end

      # Example: "invoice"
      def report_name
        raise NotImplementedError, "#{self.class} must implement #report_name"
      end
    end
  end
end
