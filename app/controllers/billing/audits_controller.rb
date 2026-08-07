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
  end
end
