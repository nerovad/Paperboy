# frozen_string_literal: true

require 'test_helper'
require 'zip'

module Billing
  class XlsxReportRendererTest < ActiveSupport::TestCase
    test 'uses template colors, decimal formats, and computed totals' do
      report = MonthlyReport.new(
        operation: 'print', start_date: '2026-07-01', end_date: '2026-07-31'
      )
      columns = Array.new(26) { |index| "COLUMN#{index + 1}" }
      columns[7] = 'AMOUNT'
      columns[23] = 'QUANTITY'
      columns[24] = 'RATE'
      columns[25] = 'COST'
      rows = Array.new(2) { Array.new(26) }
      rows[0].values_at(7, 23, 24, 25).each_index do |index|
        rows[0][[7, 23, 24, 25][index]] = [10.50, 2.25, 3.50, 12.50][index]
      end
      rows[1][25] = 7.25
      result = ActiveRecord::Result.new(columns, rows)

      data = XlsxReportRenderer.new(report, { 'name' => 'Billing' }, result).call
      files = xlsx_files(data)

      sheet = worksheet(files)
      assert_equal '19.75', sheet.at_xpath("//c[@r='AC1']/v").text
      assert_equal '2', sheet.at_xpath("//c[@r='AC2']/v").text
      decimal_styles = %w[H2 X2 Y2 Z2].map { |cell| sheet.at_xpath("//c[@r='#{cell}']")['s'] }
      assert_equal 1, decimal_styles.uniq.length
      assert_includes files.fetch('xl/styles.xml'), 'numFmtId="2"'
      %w[95DCF7 D9F2D0 F1CEEE B3E5A1 F6C6AD E49EDD].each do |color|
        assert_includes files.fetch('xl/styles.xml'), color
      end
    end

    private

    def worksheet(files)
      Nokogiri::XML(files.fetch('xl/worksheets/sheet1.xml')).tap(&:remove_namespaces!)
    end

    def xlsx_files(data)
      Zip::File.open_buffer(StringIO.new(data)).to_h do |entry|
        [entry.name, entry.get_input_stream.read]
      end
    end
  end
end
