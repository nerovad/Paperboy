# frozen_string_literal: true

require 'test_helper'
require 'pdf/reader'
require 'yaml'

module Reports
  class BillingTc60TemplateTest < ActiveSupport::TestCase
    TEMPLATE = Rails.root.join('app/reports/billing/tc60/tc60.pdf')
    COLUMNS = Rails.root.join('app/reports/billing/tc60/tc60.yml')
    ALIGN = {
      'line_number' => :center, 'amount' => :right, 'posting_ref' => :center,
      'service' => :center, 'date' => :center, 'doc_nmbr' => :center,
      'quantity' => :right, 'rate' => :right, 'cost' => :right
    }.freeze

    test 'overlay column headers match the grid header and stay in their cells' do
      page = PDF::Reader.new(TEMPLATE.to_s).pages.first
      runs = page.runs(merge: false)
      baselines = []

      body_columns.each do |key, column|
        glyphs = header_glyphs(runs, column)
        assert_equal header_label(key), glyphs.map(&:text).join, key
        baselines.concat(glyphs.map { |glyph| glyph.origin.y })
        assert glyphs.all? { |glyph| inside_column?(glyph, column) }, key
        assert_header_alignment(glyphs, column, ALIGN.fetch(key, :left), key)
      end

      assert_in_delta 541, baselines.first, 0.01
      assert_equal [baselines.first], baselines.uniq
    end

    private

    def body_columns
      YAML.safe_load(COLUMNS.read, permitted_classes: [], aliases: false).fetch('body').fetch('columns')
    end

    def header_label(key)
      key == 'line_number' ? 'Line#' : key.upcase
    end

    def header_glyphs(runs, column)
      left = column.fetch('x').to_f
      right = left + column.fetch('width').to_f
      runs.select { |run| header_glyph?(run, left, right) }.sort_by { |run| run.origin.x }
    end

    def header_glyph?(run, left, right)
      return false if run.text.to_s.strip.empty?

      mid = run.origin.x + (run.width / 2.0)
      mid >= left && mid < right && run.origin.y.between?(530, 555)
    end

    def inside_column?(glyph, column)
      left = column.fetch('x').to_f
      right = left + column.fetch('width').to_f
      glyph.origin.x >= left - 0.2 && (glyph.origin.x + glyph.width) <= right + 0.2
    end

    def assert_header_alignment(glyphs, column, alignment, key)
      left = column.fetch('x').to_f
      width = column.fetch('width').to_f
      start_x = glyphs.first.origin.x
      end_x = glyphs.last.origin.x + glyphs.last.width
      case alignment
      when :right then assert_in_delta left + width - 1, end_x, 0.6, key
      when :center then assert_in_delta left + (width / 2.0), (start_x + end_x) / 2.0, 0.6, key
      else assert_in_delta left + 1, start_x, 0.6, key
      end
    end
  end
end
