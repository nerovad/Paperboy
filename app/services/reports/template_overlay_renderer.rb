# frozen_string_literal: true

require 'prawn'
require 'prawn/templates'

module Reports
  class TemplateOverlayRenderer
    DEFAULT_FONT = 'Helvetica'

    def initialize(template:, mapping:, pages:, expected_size: nil)
      @template = Pathname(template).expand_path
      @mapping = mapping.deep_stringify_keys
      @pages = pages
      @expected_size = expected_size
    end

    def call
      validate_template!

      Prawn::Document.new(margin: 0, skip_page_creation: true) do |pdf|
        pages.each_with_index do |page, index|
          pdf.start_new_page(
            template: template.to_s,
            template_page: page.fetch(:template_page, 1),
            margin: 0
          )
          draw_fields(pdf, page.fetch(:values), page.fetch(:template_page, 1))
          raise 'Template overlay created an unexpected page' unless pdf.page_count == index + 1
        end
      end.render
    end

    private

    attr_reader :template, :mapping, :pages, :expected_size

    def validate_template!
      raise ArgumentError, "Template PDF not found: #{template}" unless template.file?

      reader = PDF::Reader.new(template.to_s)
      raise ArgumentError, 'Template PDF has no pages' if reader.pages.empty?

      return unless expected_size

      reader.pages.each do |page|
        width, height = page_size(page)
        expected_width, expected_height = expected_size
        next if [width, height] == [expected_width, expected_height]

        raise ArgumentError,
              "Template page is #{width}x#{height}; expected #{expected_width}x#{expected_height}"
      end
    end

    def page_size(page)
      box = page.attributes.fetch(:MediaBox)
      [box[2].to_f - box[0].to_f, box[3].to_f - box[1].to_f]
    end

    def draw_fields(pdf, values, page_number)
      values.stringify_keys.each do |field, value|
        field_mapping = mapping.fetch(field) do
          raise ArgumentError, "No mapping for template field #{field.inspect}"
        end
        next unless field_mapping.fetch('page', page_number).to_i == page_number

        draw_field(pdf, field, value, field_mapping)
      end
    end

    def draw_field(pdf, field, value, field_mapping)
      x = field_mapping.fetch('x').to_f
      y = field_mapping.fetch('y').to_f
      width = field_mapping.fetch('width').to_f
      height = field_mapping.fetch('height').to_f
      raise ArgumentError, "Invalid dimensions for template field #{field.inspect}" if width <= 0 || height <= 0

      pdf.font(field_mapping.fetch('font', DEFAULT_FONT)) do
        pdf.text_box(
          format_value(value, field_mapping),
          at: [x, y],
          width: width,
          height: height,
          align: field_mapping.fetch('align', 'left').to_sym,
          size: field_mapping.fetch('size', 8).to_f,
          overflow: :truncate,
          disable_wrap: true
        )
      end
    end

    def format_value(value, field_mapping)
      format = field_mapping['format']
      return value.to_s unless format
      return value.strftime(format) if value.respond_to?(:strftime)

      format % value
    rescue ArgumentError, TypeError
      raise ArgumentError, "Unable to format template value #{value.inspect}"
    end
  end
end
