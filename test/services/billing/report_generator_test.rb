# frozen_string_literal: true

require 'test_helper'

module Billing
  class ReportGeneratorTest < ActiveSupport::TestCase
    test 'formats the billing period version for report names' do
      report = MonthlyReport.new(
        operation: 'print', start_date: '2026-07-01', end_date: '2026-07-31', version: 3
      )
      generator = ReportGenerator.new(report)

      assert_equal '03', generator.send(:formatted_version)
    end

    test 'names the template overlay beside the source PDF' do
      report = MonthlyReport.new(
        operation: 'print', start_date: '2026-07-01', end_date: '2026-07-31', version: 1
      )
      generator = ReportGenerator.new(report)

      assert_equal 'BM0926-TC60-Brown-Mail-overlay-v01.pdf',
                   generator.send(:overlay_pdf_name, 'BM0926-TC60-Brown-Mail-v01.pdf')
    end
  end
end
