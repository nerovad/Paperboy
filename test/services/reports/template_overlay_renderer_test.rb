# frozen_string_literal: true

require 'test_helper'
require 'prawn'

module Reports
  class TemplateOverlayRendererTest < ActiveSupport::TestCase
    test 'writes mapped values onto a landscape template' do
      template = landscape_template

      data = TemplateOverlayRenderer.new(
        template: template,
        mapping: {
          'report_date' => {
            'page' => 1, 'x' => 1000, 'y' => 730, 'width' => 150, 'height' => 20,
            'align' => 'right', 'format' => '%m/%d/%Y'
          }
        },
        pages: [{ template_page: 1, values: { report_date: Date.new(2026, 9, 10) } }],
        expected_size: [17 * 72, 11 * 72]
      ).call

      reader = PDF::Reader.new(StringIO.new(data))
      assert_equal 1, reader.page_count
      assert_includes reader.pages.first.text, '09/10/2026'
    ensure
      FileUtils.rm_f(template)
    end

    test 'rejects a template with the wrong page size' do
      template = Tempfile.new(['portrait', '.pdf'])
      Prawn::Document.generate(template.path, page_size: 'LETTER') { |pdf| pdf.text('template') }

      error = assert_raises(ArgumentError) do
        TemplateOverlayRenderer.new(
          template: template.path,
          mapping: {},
          pages: [{ template_page: 1, values: {} }],
          expected_size: [17 * 72, 11 * 72]
        ).call
      end

      assert_match 'expected 1224x792', error.message
    ensure
      template&.close!
    end

    private

    def landscape_template
      file = Tempfile.new(['landscape', '.pdf'])
      Prawn::Document.generate(file.path, page_size: [17 * 72, 11 * 72]) do |pdf|
        pdf.text('preprinted template')
      end
      file.close
      file.path
    end
  end
end
