# frozen_string_literal: true

require 'prawn'
require 'prawn/templates'
require 'yaml'

module Billing
  # A fixed grid avoids Prawn's expensive table measurement for large reports.
  # rubocop:disable Metrics/ClassLength
  class PdfReportRenderer
    DATE_FORMAT = '%m/%d/%y'
    ROWS_PER_PAGE = 29
    OVERLAY_ROWS_PER_PAGE = 30
    PAGE_SIZE = [17 * 72, 11 * 72].freeze
    OVERLAY_PAGE_SIZE = [11 * 72, 8.5 * 72].freeze
    ROW_HEIGHT = 8 * 72 / 25.4
    MARGIN = 8 * 72 / 25.4
    COLUMN_WIDTHS = [
      7, 10, 13, 12, 12, 12, 12, 14, 7, 10, 13, 12, 13,
      12, 12, 14, 16, 10, 13, 50, 40, 31, 31, 11, 10, 12
    ].freeze
    COLUMN_ALIGNMENTS = %i[
      left left left left left left left right left left left left left
      left left center center center center left left left left right right right
    ].freeze
    TEXT_COLUMNS = %w[DOC_NMBR DOC_NUBR DOC_NUMBR CUNIT COBJECT CACTIVTY
                      CFUNCTION CPROGRAM CPHASE SPHASE STASK].freeze

    def initialize(report, definition, result, overlay: false)
      @report = report
      @definition = definition
      @result = result
      @overlay = overlay
    end

    def call
      return overlay_call if overlay

      Prawn::Document.new(page_size: PAGE_SIZE, margin: MARGIN, compress: true) do |pdf|
        render_pages(pdf)
      end.render
    end

    private

    attr_reader :report, :definition, :result, :overlay

    def overlay_call
      template = Reports::TemplateCatalog.new.find(
        group: 'billing', filename: 'template.pdf'
      )
      mapping = overlay_mapping
      pages = overlay_batches.each_with_index.map do |rows, index|
        {
          template_page: 1,
          values: overlay_values(index),
          rows: rows,
          offset: index * OVERLAY_ROWS_PER_PAGE
        }
      end

      Reports::TemplateOverlayRenderer.new(
        template: template,
        mapping: mapping,
        pages: pages,
        expected_size: OVERLAY_PAGE_SIZE,
        page_renderer: method(:draw_overlay_rows)
      ).call
    end

    def overlay_mapping
      config = YAML.safe_load(
        Rails.root.join('config/reports/billing/template.yml').read,
        permitted_classes: [], aliases: false
      )
      config.fetch('header').fetch('fields').merge(config.fetch('footer').fetch('fields'))
    end

    def overlay_values(page)
      {
        'date_range' => date_range,
        'filename' => File.basename(definition.fetch('pdffile')),
        'billing_summary' => billing_summary,
        'prepared_by' => "Prepared by GSA Business Support Services on #{Time.current}",
        'page_number' => "Page #{page + 1} of #{overlay_batches.length}"
      }
    end

    def draw_overlay_rows(pdf, page, _index)
      rows = page.fetch(:rows)
      rows.each_with_index do |row, index|
        draw_overlay_row(pdf, [page.fetch(:offset, 0) + index + 1] + printable_row(row), index)
      end
    end

    def draw_overlay_row(pdf, values, index)
      config = overlay_body_config
      rows = config.fetch('table').fetch('rows')
      y = rows.fetch('first_baseline').to_f - (index * rows.fetch('row_height').to_f)
      columns = ['line_number'] + result.columns.map { |column| overlay_column_name(column) }
      values.each_with_index do |value, column_index|
        field = config.fetch('columns').fetch(columns.fetch(column_index))
        draw_overlay_cell(pdf, value, field, y)
      end
    end

    def overlay_column_name(column)
      name = column.to_s.downcase
      return 'doc_nmbr' if %w[doc_nmbr doc_nubr doc_numbr].include?(name)
      return 'cactivity' if name == 'cactivty'

      name
    end

    def draw_overlay_cell(pdf, value, field, y)
      x = field.fetch('x').to_f
      width = field.fetch('width').to_f
      text = truncate(pdf_value(value), width)
      pdf.font('Helvetica', size: 5) do
        pdf.text_box(
          text,
          at: [x + 1, y + 5],
          width: width - 2,
          height: 10,
          align: field.fetch('align', 'left').to_sym,
          overflow: :truncate,
          disable_wrap: true
        )
      end
    end

    def overlay_body_config
      @overlay_body_config ||= YAML.safe_load(
        Rails.root.join('config/reports/billing/template.yml').read,
        permitted_classes: [], aliases: false
      ).fetch('body')
    end

    def overlay_batches
      @overlay_batches ||= result.rows.each_slice(OVERLAY_ROWS_PER_PAGE).to_a.presence || [[]]
    end

    def render_pages(pdf)
      batches.each_with_index do |rows, index|
        pdf.start_new_page unless index.zero?
        draw_header(pdf)
        draw_grid(pdf, rows, index * ROWS_PER_PAGE)
        draw_footer(pdf, index + 1)
      end
    end

    def batches
      @batches ||= result.rows.each_slice(ROWS_PER_PAGE).to_a.presence || [[]]
    end

    def draw_header(pdf)
      pdf.font_size(8) do
        header_text(pdf, date_range, 0, 380, :left)
        header_text(pdf, File.basename(definition.fetch('pdffile')), 380, 300, :center)
        header_text(pdf, billing_summary, 680, pdf.bounds.width - 680, :right)
      end
      pdf.move_down(ROW_HEIGHT + 3)
    end

    def header_text(pdf, text, x, width, alignment)
      pdf.text_box(text, at: [x, pdf.cursor], width: width, height: ROW_HEIGHT, align: alignment)
    end

    def billing_summary
      total = result.rows.sum { |row| numeric_value(row[25]) }
      "Billing Amount: #{format('%.2f', total)} Number of Lines: #{result.rows.length}"
    end

    def draw_grid(pdf, rows, offset)
      return if result.columns.empty?

      widths = column_widths(pdf)
      alignments = column_alignments
      top = pdf.cursor
      pdf.fill_color('C8C8C8')
      pdf.fill_rectangle([0, top], widths.sum, ROW_HEIGHT)
      pdf.fill_color('000000')
      pdf.font('Helvetica', style: :bold, size: 5)
      draw_row(pdf, ['Line#'] + result.columns, widths, alignments)
      pdf.font('Helvetica', style: :normal, size: 5)
      rows.each_with_index do |row, index|
        draw_row(pdf, [offset + index + 1] + printable_row(row), widths, alignments)
      end
      draw_grid_lines(pdf, widths, top, rows.length + 1)
    end

    def draw_row(pdf, values, widths, alignments)
      y = pdf.cursor
      x = 0
      values.each_with_index do |value, index|
        width = widths.fetch(index)
        draw_cell(pdf, value, x, y, width, alignments.fetch(index))
        x += width
      end
      pdf.move_down(ROW_HEIGHT)
    end

    def draw_grid_lines(pdf, widths, top, row_count)
      pdf.stroke_color('000000')
      x_positions = widths.each_with_object([0]) { |width, values| values << (values.last + width) }
      x_positions.each { |x| pdf.stroke_line([x, top], [x, top - (row_count * ROW_HEIGHT)]) }
      (0..row_count).each do |row|
        y = top - (row * ROW_HEIGHT)
        pdf.stroke_line([0, y], [widths.sum, y])
      end
    end

    def draw_cell(pdf, value, x, y, width, alignment)
      text = truncate(pdf_value(value), width)
      text_width = [text.length * 2.5, width - 2].min
      text_x = aligned_x(x, width, text_width, alignment)
      encoded_text = pdf.font.normalize_encoding(text)
      pdf.send(:draw_text!, encoded_text, at: [text_x, y - ROW_HEIGHT + 7], kerning: false)
    end

    def printable_row(row)
      row.each_with_index.map do |value, index|
        text_column?(index) ? value.to_s : value
      end
    end

    def text_column?(index)
      TEXT_COLUMNS.include?(result.columns[index].to_s.upcase)
    end

    def truncate(text, width)
      maximum = [(width - 2).fdiv(2.7).floor, 0].max
      text.length > maximum ? text.first(maximum) : text
    end

    def aligned_x(x, width, text_width, alignment)
      case alignment
      when :right then x + width - text_width - 1
      when :center then x + ((width - text_width) / 2)
      else x + 1
      end
    end

    def draw_footer(pdf, page)
      pdf.move_down(2)
      pdf.font('Helvetica', style: :italic, size: 5)
      header_text(pdf, "Prepared by GSA Business Support Services on #{Time.current}",
                  0, pdf.bounds.width / 2, :left)
      header_text(pdf, "Page #{page} of #{batches.length}", pdf.bounds.width / 2,
                  pdf.bounds.width / 2, :right)
    end

    def column_widths(pdf)
      weights = result.columns.length == COLUMN_WIDTHS.length ? COLUMN_WIDTHS : Array.new(result.columns.length, 1)
      available = pdf.bounds.width - line_width(pdf)
      [line_width(pdf)] + weights.map { |weight| available * weight.fdiv(weights.sum) }
    end

    def column_alignments
      values = result.columns.length == COLUMN_ALIGNMENTS.length ? COLUMN_ALIGNMENTS : Array.new(result.columns.length, :left)
      [:center] + values
    end

    def line_width(pdf)
      pdf.bounds.width * 6.fdiv(415)
    end

    def pdf_value(value)
      case value
      when Date, Time, DateTime then value.strftime(DATE_FORMAT)
      when Float then format('%.2f', value)
      else value.to_s
      end
    end

    def formatted_report_date(value)
      Date.iso8601(value).strftime(DATE_FORMAT)
    end

    def date_range
      format('Date Range: %s to %s', formatted_report_date(report.start_date),
             formatted_report_date(report.end_date))
    end

    def numeric_value(value)
      Float(value || 0)
    rescue ArgumentError, TypeError
      0
    end
  end
  # rubocop:enable Metrics/ClassLength
end
