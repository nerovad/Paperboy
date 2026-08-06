# frozen_string_literal: true

require 'test_helper'
require 'zip'

module Billing
  class XlsxReportRendererTest < ActiveSupport::TestCase
    test 'uses template colors and adds billing formulas' do
      report = MonthlyReport.new(
        operation: 'print', start_date: '2026-07-01', end_date: '2026-07-31'
      )
      columns = %w[CUNIT COBJECT COST]
      result = ActiveRecord::Result.new(columns, [['A', 'B', 12.50], ['C', 'D', 7.25]])

      data = XlsxReportRenderer.new(report, { 'name' => 'Billing' }, result).call
      files = xlsx_files(data)

      assert_includes files.fetch('xl/worksheets/sheet1.xml'), '<f>SUM(C:C)</f>'
      assert_includes files.fetch('xl/worksheets/sheet1.xml'), '<f>COUNTA(A:A)-1</f>'
      assert_includes files.fetch('xl/worksheets/sheet1.xml'), 'Billing Amount'
      assert_includes files.fetch('xl/worksheets/sheet1.xml'), 'Number of Lines'
      %w[95DCF7 D9F2D0 F1CEEE B3E5A1 F6C6AD E49EDD].each do |color|
        assert_includes files.fetch('xl/styles.xml'), color
      end
    end

    private

    def xlsx_files(data)
      Zip::File.open_buffer(StringIO.new(data)).to_h do |entry|
        [entry.name, entry.get_input_stream.read]
      end
    end
  end
end
