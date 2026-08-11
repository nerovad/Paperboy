# frozen_string_literal: true

require 'test_helper'

module Billing
  class ActiveBillingPeriodTest < ActiveSupport::TestCase
    test 'defaults new periods to version one' do
      period = ActiveBillingPeriod.new

      assert_equal 1, period.version
    end

    test 'rejects a reversed date range' do
      period = ActiveBillingPeriod.new(
        version: 1,
        fiscal_year: 'FY27',
        apmon: 'AP01',
        start_date: Date.new(2026, 7, 31),
        end_date: Date.new(2026, 7, 1)
      )

      assert_not period.valid?
      assert_includes period.errors[:end_date], 'must be on or after start date'
    end
  end
end
