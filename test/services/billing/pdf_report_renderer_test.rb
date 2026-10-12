# frozen_string_literal: true

require 'test_helper'
require 'pdf/reader'

module Billing
  class PdfReportRendererTest < ActiveSupport::TestCase
    test 'renders fixed-size report pages' do
      report = print_report
      columns = Array.new(26) { |index| "Column #{index}" }
      rows = Array.new(60) { |index| Array.new(26, index) }
      result = ActiveRecord::Result.new(columns, rows)

      data = PdfReportRenderer.new(report, { 'pdffile' => 'report.pdf' }, result).call
      reader = PDF::Reader.new(StringIO.new(data))

      assert_equal 3, reader.page_count
      assert_operator data.bytesize, :<, 100_000
    end

    test 'renders document numbers as identifiers instead of decimal values' do
      report = print_report
      columns = Array.new(26) { |index| "Column #{index}" }
      columns[19] = 'DOC_NMBR'
      row = Array.new(26)
      row[19] = 874_940_000_000.0
      result = ActiveRecord::Result.new(columns, [row])

      data = PdfReportRenderer.new(report, { 'pdffile' => 'report.pdf' }, result).call
      text = PDF::Reader.new(StringIO.new(data)).pages.first.text

      assert_includes text, '874940000000.0'
      refute_includes text, '874940000000.00'
    end

    test 'renders accounting codes as text to preserve their formatting' do
      report = print_report
      columns = %w[CUNIT COBJECT CACTIVITY CFUNCTION CPROGRAM CPHASE SPHASE STASK]
      result = ActiveRecord::Result.new(columns, [%w[001 002 003 004 005 006 007 008]])

      data = PdfReportRenderer.new(report, { 'pdffile' => 'report.pdf' }, result).call
      text = PDF::Reader.new(StringIO.new(data)).pages.first.text

      %w[001 002 003 004 005 006 007 008].each do |code|
        assert_includes text, code
      end
    end

    test 'renders quantity with three decimals and rate with four' do
      report = print_report
      columns = Array.new(26) { |index| "Column #{index}" }
      columns[7] = 'AMOUNT'
      columns[23] = 'QUANTITY'
      columns[24] = 'RATE'
      columns[25] = 'COST'
      row = Array.new(26)
      row[7] = 10.5
      row[23] = 2.251
      row[24] = 3.5075
      row[25] = 12.5
      whole = Array.new(26)
      whole[23] = 2.0
      whole[24] = 4.5
      result = ActiveRecord::Result.new(columns, [row, whole])

      data = PdfReportRenderer.new(report, { 'pdffile' => 'report.pdf' }, result).call
      text = PDF::Reader.new(StringIO.new(data)).pages.first.text

      assert_includes text, '10.50'
      assert_includes text, '2.251'
      assert_includes text, '3.5075'
      assert_includes text, '12.50'
      assert_includes text, '2.000'
      assert_includes text, '4.5000'
      refute_includes text, '3.51'
    end

    test 'keeps right-aligned numeric headers inside the following column' do
      report = print_report
      columns = %w[CUNIT COBJECT CACTIVITY CFUNCTION CPROGRAM CPHASE CTASK AMOUNT SUNIT
                   SOBJECT SACTIVITY SFUNCTION SPROGRAM SPHASE STASK POSTING_REF SERVICE
                   DATE DOC_NMBR DESCRIPTION OTHER1 OTHER2 OTHER3 QUANTITY RATE COST]
      row = Array.new(columns.length)
      row[7] = 10.5
      row[23] = 2.251
      row[24] = 3.5075
      row[25] = 12.5
      result = ActiveRecord::Result.new(columns, [row])

      pdf = PdfReportRenderer.new(report, { 'pdffile' => 'report.pdf' }, result).call
      page = PDF::Reader.new(StringIO.new(pdf)).pages.first
      assert_includes page.text, 'AMOUNT SUNIT'
      refute_includes page.text, 'AMOUNSTUNIT'
      assert text_end(page, 'QUANTITY') <= text_start(page, 'RATE')
      assert text_end(page, 'RATE') <= text_start(page, 'COST')
      assert text_end(page, 'COST') <= page.width - PdfReportRenderer::MARGIN
    end

    test 'formats dates as month, day, and two-digit year' do
      report = print_report
      result = ActiveRecord::Result.new(['DATE'], [[Date.new(2026, 7, 15)]])

      data = PdfReportRenderer.new(report, { 'pdffile' => 'report.pdf' }, result).call
      text = PDF::Reader.new(StringIO.new(data)).pages.first.text

      assert_includes text, 'Date Range: 07/01/26 to 07/31/26'
      assert_includes text, '07/15/26'
      refute_includes text, '2026-07-15'
    end

    private

    def print_report
      MonthlyReport.new(operation: 'print', start_date: '2026-07-01', end_date: '2026-07-31')
    end

    def text_start(page, text)
      text_run(page, text).origin.x
    end

    def text_end(page, text)
      run = text_run(page, text)
      run.origin.x + run.width
    end

    def text_run(page, text)
      page.runs.find { |run| run.text == text } || flunk("missing PDF text #{text}")
    end
  end
end
