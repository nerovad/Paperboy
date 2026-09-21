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

    test 'redirects completed billing runs to the audit' do
      report = MonthlyReport.new(
        operation: 'run', start_date: '2026-07-01', end_date: '2026-07-31', version: 6
      )
      controller = MonthlyReportsController.new
      controller.instance_variable_set(:@report, report)
      runner = Minitest::Mock.new
      runner.expect(:call, nil)
      redirect = nil

      MonthlyReportRunner.stub(:new, runner) do
        controller.stub(:billing_audit_path, '/billing/audit') do
          controller.stub(:redirect_to, ->(path, notice:) { redirect = [path, notice] }) do
            controller.send(:run_monthly_billing)
          end
        end
      end

      assert_equal ['/billing/audit', 'Monthly billing complete'], redirect
      runner.verify
    end
  end
end
