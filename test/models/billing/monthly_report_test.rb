# frozen_string_literal: true

require 'test_helper'

module Billing
  class MonthlyReportTest < ActiveSupport::TestCase
    test 'defines the procedures used by each operation' do
      run = MonthlyReport.new(operation: 'run')
      print = MonthlyReport.new(operation: 'print')
      email = MonthlyReport.new(operation: 'email')

      assert_equal ['GSABSS.dbo.MonthlyBilling'], run.procedure_names
      assert_equal print.procedure_names, email.procedure_names
      assert_equal 2, print.procedure_names.length
    end

    test 'accepts an ordered date range' do
      report = MonthlyReport.new(
        operation: 'print', start_date: '2026-08-01', end_date: '2026-08-31'
      )

      assert report.valid?
    end

    test 'rejects a reversed date range' do
      report = MonthlyReport.new(
        operation: 'email', start_date: '2026-08-31', end_date: '2026-08-01'
      )

      assert_not report.valid?
      assert_includes report.errors[:end_date], 'must be on or after start date'
    end
  end
end
