# app/reports/base/pdf_renderer.rb
module Reports
  module Base
    class PdfRenderer
      def initialize(template:, mapping:, data:, report:)
        @template = template
        @mapping  = mapping
        @data     = data
        @report   = report
      end

      def render
        output_path = Rails.root.join("tmp/#{filename}")

        Prawn::Document.generate(output_path, template: @template) do |pdf|
          @mapping.each do |field, pos|
            value = @data[field.to_sym].to_s
            pdf.draw_text value, at: [pos["x"], pos["y"]]
          end
        end

        output_path.to_s
      end

      private

      def filename
        "#{@report}_#{Time.now.strftime('%Y%m%d_%H%M%S')}.pdf"
      end
    end
  end
end
