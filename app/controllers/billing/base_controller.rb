# frozen_string_literal: true

module Billing
  # Base controller for the Billing app. Every Billing controller should
  # inherit from this so the ACL gate below is applied consistently.
  class BaseController < ApplicationController
    include ApplicationAccessGate

    gate_application 'billing', label: 'Billing'

    private

    def set_active_billing_period
      @active_billing_period = ActiveBillingPeriod.current
    end
  end
end
