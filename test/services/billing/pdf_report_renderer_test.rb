# frozen_string_literal: true

require 'test_helper'
require 'pdf/reader'

module Billing
  class PdfReportRendererTest < ActiveSupport::TestCase
    test 'renders fixed-size report pages' do
      report = MonthlyReport.new(
        operation: 'print', start_date: '2026-07-01', end_date: '2026-07-31'
      )
      columns = Array.new(26) { |index| "Column #{index}" }
      rows = Array.new(60) { |index| Array.new(26, index) }
      result = ActiveRecord::Result.new(columns, rows)

      data = PdfReportRenderer.new(report, { 'pdffile' => 'report.pdf' }, result).call
      reader = PDF::Reader.new(StringIO.new(data))

      assert_equal 3, reader.page_count
      assert_operator data.bytesize, :<, 100_000
    end
  end
end
