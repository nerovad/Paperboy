# frozen_string_literal: true

module Billing
  class AuditsController < BaseController
    before_action :require_system_admin

    def show
      @active_billing_period = ActiveBillingPeriod.current
      return unless @active_billing_period

      @billing_type_audits = BillingTypeAudit.new(@active_billing_period).results
      @audit_groups = Audit.new(@active_billing_period).results
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

    def rows
      @active_billing_period = ActiveBillingPeriod.current
      @audit_check = Audit.find_check(params[:key])
      raise ActiveRecord::RecordNotFound if @audit_check.nil? || params[:value].blank?

      @invalid_value = params[:value]
      @tc60_rows = AuditRows.new(@active_billing_period, @audit_check, @invalid_value).results if @active_billing_period
    rescue ActiveRecord::RecordNotFound
      raise
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.error("Billing audit rows failed: #{e.class}: #{e.message}")
      @audit_error = 'The TC60 audit rows could not be loaded.'
    end

    def type_rows
      @active_billing_period = ActiveBillingPeriod.current
      @billing_type = BillingType.find_by(TYPE: params[:code], ACTIVE: true)
      raise ActiveRecord::RecordNotFound unless @billing_type

      @tc60_rows = BillingTypeAudit.new(@active_billing_period).error_rows(@billing_type.code) if @active_billing_period
    rescue ActiveRecord::RecordNotFound
      raise
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.error("Billing type audit rows failed: #{e.class}: #{e.message}")
      @audit_error = 'The Billing type error rows could not be loaded.'
    end
  end
end
