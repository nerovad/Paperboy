# frozen_string_literal: true

module Billing
  class BillingTypesController < BaseController
    ACTIVE_VALUES = %w[0 1].freeze

    before_action -> { require_app_feature('billing', 'enable_billing', fallback: billing_root_path) }
    before_action :set_active_billing_period
    before_action :load_billing_types

    def index; end

    def update
      values = active_params.to_h
      validate_values!(values)

      BillingType.transaction do
        @billing_types.each do |billing_type|
          billing_type.update!(active: values.fetch(billing_type.code) == '1')
        end
      end
      redirect_to billing_billing_types_path, notice: 'Billing types updated successfully.'
    rescue ActiveRecord::ActiveRecordError, KeyError, ActionController::ParameterMissing, ArgumentError => e
      Rails.logger.error("Billing types update failed: #{e.class}: #{e.message}")
      redirect_to billing_billing_types_path, alert: 'Billing types could not be updated.'
    end

    private

    def load_billing_types
      @billing_types = BillingType.order(:TYPE).to_a
    end

    def active_params
      params.require(:active).permit(*@billing_types.map(&:code))
    end

    def validate_values!(values)
      expected_codes = @billing_types.map(&:code).sort
      raise ArgumentError unless values.keys.sort == expected_codes
      raise ArgumentError unless values.values.all? { |value| ACTIVE_VALUES.include?(value) }
    end
  end
end
