# frozen_string_literal: true

module Reports
  class BillingTemplateRenderer
    LANDSCAPE_LETTER = [11 * 72, 8.5 * 72].freeze

    def initialize(template:, mapping:, values:, template_page: 1)
      @template = template
      @mapping = mapping
      @values = values
      @template_page = template_page
    end

    def call
      TemplateOverlayRenderer.new(
        template: template,
        mapping: mapping,
        pages: [{ template_page: template_page, values: values }],
        expected_size: LANDSCAPE_LETTER
      ).call
    end

    private

    attr_reader :template, :mapping, :values, :template_page
  end
end
