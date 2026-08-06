# frozen_string_literal: true

module Billing
  class MonthlyReportsController < BaseController
    before_action :require_system_admin
    before_action :require_valid_operation
    before_action :load_active_billing_period

    def show
      @report = MonthlyReport.new(operation: params[:operation])
      apply_active_period
      render :show
    end

    def create
      @report = MonthlyReport.new(operation: params[:operation])
      apply_active_period
      return render_invalid unless @report.valid?

      process_report
    rescue StandardError => e
      Rails.logger.error("Billing monthly report failed: #{e.class}: #{e.message}")
      redirect_to billing_monthly_report_path(@report.operation),
                  alert: 'The billing report could not be processed.'
    end

    private

    def require_valid_operation
      return if MonthlyReport::OPERATIONS.key?(params[:operation])

      redirect_to billing_root_path, alert: 'Unknown monthly report operation.'
    end

    def load_active_billing_period
      @active_billing_period = ActiveBillingPeriod.current
      return if @active_billing_period

      redirect_to billing_reporting_period_path,
                  alert: 'Select an active billing period before running Billing reports.'
    end

    def apply_active_period
      @report.start_date = @active_billing_period.start_date.iso8601
      @report.end_date = @active_billing_period.end_date.iso8601
    end

    def render_invalid
      flash.now[:alert] = @report.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end

    def process_report
      case @report.operation
      when 'run' then run_monthly_billing
      when 'print' then print_billing_reports
      when 'email' then email_billing_reports
      end
    end

    def run_monthly_billing
      MonthlyReportRunner.new(@report).call
      redirect_to billing_dashboard_path, notice: 'Monthly billing complete'
    end

    def print_billing_reports
      artifacts = ReportGenerator.new(@report).call
      ReportWriter.new(artifacts).call
      redirect_to billing_reports_path,
                  notice: 'Billing reports generated successfully.'
    end

    def email_billing_reports
      recipients = ENV.fetch('BILLING_REPORT_RECIPIENTS', '').split(/[;,]/).map(&:strip).compact_blank
      if recipients.empty?
        @report.errors.add(:base, 'BILLING_REPORT_RECIPIENTS is not configured')
        return render_invalid
      end

      Billing::ReportGenerationJob.perform_later(
        operation: @report.operation,
        start_date: @report.start_date,
        end_date: @report.end_date,
        recipients: recipients
      )
      redirect_to billing_reports_path,
                  notice: 'Billing report generation and email delivery started.'
    end
  end
end
