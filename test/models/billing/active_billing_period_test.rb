# frozen_string_literal: true

require 'test_helper'

module Billing
  class ActiveBillingPeriodTest < ActiveSupport::TestCase
    test 'rejects a reversed date range' do
      period = ActiveBillingPeriod.new(
        singleton_id: 1,
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
