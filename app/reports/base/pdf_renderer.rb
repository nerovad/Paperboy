# app/reports/base/pdf_renderer.rb
# app/reports/base/pdf_renderer.rb
require "prawn"

module Reports
  module Base
    class PdfRenderer
      attr_reader :template, :mapping, :data, :report

      def initialize(template:, mapping:, data:, report:)
        @template = template
        @mapping  = mapping
        @data     = data
        @report   = report
      end

      def render
        output_path = build_output_path

        Prawn::Document.generate(output_path, template: template) do |pdf|
          renderer = load_renderer(pdf)

          renderer.render
        end

        output_path
      end

      private

      # ----------------------------------------------------------------------
      # Renderer loading
      # ----------------------------------------------------------------------
      def load_renderer(pdf)
        renderer_file =
          Rails.root.join(
            "app/pdfs/#{report}/#{report}_renderer.rb"
          )

        unless File.exist?(renderer_file)
          raise LoadError,
            "Missing renderer file: #{renderer_file}"
        end

        require renderer_file

        renderer_class =
          "Reports::#{report.camelize}::Renderer".constantize

        renderer_class.new(
          pdf:     pdf,
          data:    data,
          mapping: mapping
        )
      rescue NameError => e
        raise NameError,
          "Renderer class Reports::#{report.camelize}::Renderer not found " \
          "in #{renderer_file}: #{e.message}"
      end

      # ----------------------------------------------------------------------
      # Output path
      # ----------------------------------------------------------------------
      def build_output_path
        timestamp = Time.now.strftime("%Y%m%d-%H%M%S")

        Rails.root.join(
          "tmp/reports/#{report}-#{timestamp}.pdf"
        ).to_s
      end
    end
  end
end
