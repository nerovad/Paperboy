# frozen_string_literal: true

module Billing
  class ReportingPeriodsController < BaseController
    before_action -> { require_app_feature('billing', 'reporting_period', fallback: billing_root_path) }
    before_action :load_periods

    def show
      @active_billing_period = ActiveBillingPeriod.current
      @selected_apmon = @active_billing_period&.apmon || current_period&.fetch('apmon', nil)
    end

    def update
      period = @fiscal_periods.find { |candidate| candidate.fetch('apmon') == params[:apmon] }
      raise ActiveRecord::RecordNotFound unless period

      ActiveBillingPeriod.activate!(period)
      redirect_to billing_reporting_period_path, notice: 'Active billing period updated successfully.'
    rescue ActiveRecord::ActiveRecordError, KeyError => e
      Rails.logger.error("Billing reporting period update failed: #{e.class}: #{e.message}")
      redirect_to billing_reporting_period_path, alert: 'The active billing period could not be updated.'
    end

    private

    def load_periods
      @fiscal_periods = FiscalPeriods.for
    end

    def current_period
      @fiscal_periods.find do |period|
        Date.current.between?(period.fetch('sdate').to_date, period.fetch('edate').to_date)
      end
    end
  end
end
