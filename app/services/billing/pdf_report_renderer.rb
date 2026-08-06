# frozen_string_literal: true

require 'prawn'

module Billing
  # A fixed grid avoids Prawn's expensive table measurement for large reports.
  # rubocop:disable Metrics/ClassLength
  class PdfReportRenderer
    ROWS_PER_PAGE = 29
    PAGE_SIZE = [17 * 72, 11 * 72].freeze
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

    def initialize(report, definition, result)
      @report = report
      @definition = definition
      @result = result
    end

    def call
      Prawn::Document.new(page_size: PAGE_SIZE, margin: MARGIN, compress: true) do |pdf|
        render_pages(pdf)
      end.render
    end

    private

    attr_reader :report, :definition, :result

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
        header_text(pdf, "Date Range: #{report.start_date} to #{report.end_date}", 0, 380, :left)
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
        draw_row(pdf, [offset + index + 1] + row, widths, alignments)
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
      when Date, Time, DateTime then value.strftime('%Y-%m-%d')
      when Float then format('%.2f', value)
      else value.to_s
      end
    end

    def numeric_value(value)
      Float(value || 0)
    rescue ArgumentError, TypeError
      0
    end
  end
  # rubocop:enable Metrics/ClassLength
end
