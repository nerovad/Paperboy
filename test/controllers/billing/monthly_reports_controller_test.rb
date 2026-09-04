# frozen_string_literal: true

require 'test_helper'

module Billing
  class MonthlyReportsControllerTest < ActiveSupport::TestCase
    test 'queues print report generation for the active period' do
      report = MonthlyReport.new(
        operation: 'print', start_date: '2026-07-01', end_date: '2026-07-31', version: 3
      )
      controller = MonthlyReportsController.new
      controller.instance_variable_set(:@report, report)
      arguments = nil

      ReportGenerationJob.stub(:perform_later, ->(**values) { arguments = values }) do
        controller.stub(:billing_reports_path, '/billing/reports') do
          controller.stub(:redirect_to, nil) do
            controller.send(:print_billing_reports)
          end
        end
      end

      assert_equal(
        {
          operation: 'print', start_date: '2026-07-01', end_date: '2026-07-31', version: 3
        },
        arguments
      )
    end
  end
end
