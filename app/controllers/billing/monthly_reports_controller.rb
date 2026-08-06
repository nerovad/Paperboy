# frozen_string_literal: true

module Billing
  class MonthlyReportsController < BaseController
    before_action :require_system_admin
    before_action :require_valid_operation
    before_action :load_periods

    def show
      @report = MonthlyReport.new(operation: params[:operation])
      apply_current_period
      render :show
    end

    def create
      @report = MonthlyReport.new(report_params.merge(operation: params[:operation]))
      return render_invalid unless @report.valid?

      process_report
    rescue StandardError => e
      Rails.logger.error("Billing monthly report failed: #{e.class}: #{e.message}")
      redirect_to billing_monthly_report_path(@report.operation),
                  alert: 'The billing report could not be processed.'
    end

    private

    def report_params
      params.expect(billing_monthly_report: %i[start_date end_date])
    end

    def require_valid_operation
      return if MonthlyReport::OPERATIONS.key?(params[:operation])

      redirect_to billing_root_path, alert: 'Unknown monthly report operation.'
    end

    def load_periods
      @fiscal_periods = FiscalPeriods.for
    end

    def apply_current_period
      period = @fiscal_periods.find do |candidate|
        Date.current.between?(candidate['sdate'].to_date, candidate['edate'].to_date)
      end
      return unless period

      @report.start_date = period['sdate'].to_date.iso8601
      @report.end_date = period['edate'].to_date.iso8601
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
      redirect_to billing_root_path, notice: 'Monthly billing complete'
    end

    def print_billing_reports
      artifacts = ReportGenerator.new(@report).call
      filename = "billing-reports-#{@report.start_date}-#{@report.end_date}.zip"
      send_data ReportBundle.new(artifacts).call, filename: filename, type: 'application/zip'
    end

    def email_billing_reports
      recipients = ENV.fetch('BILLING_REPORT_RECIPIENTS', '').split(/[;,]/).map(&:strip).compact_blank
      if recipients.empty?
        @report.errors.add(:base, 'BILLING_REPORT_RECIPIENTS is not configured')
        return render_invalid
      end

      ReportGenerator.new(@report).call.each do |artifact|
        recipients.each { |recipient| BillingReportMailer.monthly_report(recipient, artifact).deliver_now }
      end
      redirect_to billing_root_path, notice: 'Billing reports emailed successfully'
    end
  end
end
