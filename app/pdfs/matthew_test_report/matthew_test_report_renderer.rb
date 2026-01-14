# app/pdfs/matthew_test_report/matthew_test_report_renderer.rb
#
# Developer-editable Prawn renderer.
#
# Receives:
#   - pdf      Prawn::Document (already initialized with template + margin)
#   - data     Array<Hash> (one hash per SQL row)
#   - mapping  YAML field coordinates
#   - template Path to PDF template (String)
#
# Contract:
#   - One SQL row = one PDF page
#   - Absolute coordinates assume margin: 0

# TODO: Update renderer to match the report-specific stored procedue.

module MatthewTestReport
  class Renderer
      def initialize(pdf:, data:, mapping:, template:)
        @pdf      = pdf
        @data     = data
        @mapping  = mapping
        @template = template.to_s
      end

      def render
        if @data.empty?
          @pdf.start_new_page
          @pdf.text "No data returned from stored procedure.", style: :bold
          return
        end

        @data.each do |row|
          @pdf.start_new_page

          logo_path = Rails.root.join("app/assets/images/report_logo.png")
          if File.exist?(logo_path)
            @pdf.image(logo_path.to_s, at: [38, 780], width: 600)
          else
            @pdf.text_box("MISSING LOGO", at: [38, 780], width: 200, height: 20)
          end

          @mapping.each do |field, coords|
            value = row[field.to_s] || ""

            x = coords["x"].to_i
            y = coords["y"].to_i

            @pdf.text_box(
              "#{field.to_s.upcase}:",
              at: [x - 90, y],
              width: 90,
              height: 20,
              overflow: :truncate,
              disable_wrap: true
            )

            @pdf.text_box(
              value.to_s,
              at: [x, y],
              width: 200,
              height: 20,
              overflow: :truncate,
              disable_wrap: true
            )
          end
        end

        @pdf.number_pages(
          "<page> of <total>",
          at: [500, 20],
          width: 100,
          align: :right
        )
      end

  end
end
