# frozen_string_literal: true

module Billing
  class AuditsController < BaseController
    before_action :require_system_admin

    def show
      @active_billing_period = ActiveBillingPeriod.current
      @audit_groups = Audit.new(@active_billing_period).results if @active_billing_period
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.error("Billing audit failed: #{e.class}: #{e.message}")
      @audit_error = 'The Billing audit could not be loaded.'
    end

    def detail
      @active_billing_period = ActiveBillingPeriod.current
      @audit_check = Audit.find_check(params[:key])
      raise ActiveRecord::RecordNotFound unless @audit_check

      @audit_details = Audit.new(@active_billing_period).details(@audit_check.key) if @active_billing_period
    rescue ActiveRecord::RecordNotFound
      raise
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.error("Billing audit detail failed: #{e.class}: #{e.message}")
      @audit_error = 'The Billing audit detail could not be loaded.'
    end
  end
end
