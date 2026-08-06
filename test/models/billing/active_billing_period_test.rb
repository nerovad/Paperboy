# frozen_string_literal: true

require 'test_helper'

module Billing
  class ActiveBillingPeriodTest < ActiveSupport::TestCase
    test 'formats the reusable active period text' do
      period = ActiveBillingPeriod.new(
        singleton_id: 1,
        fiscal_year: 'FY27',
        apmon: 'AP01',
        start_date: Date.new(2026, 7, 1),
        end_date: Date.new(2026, 7, 31)
      )

      assert_equal <<~TEXT.chomp, period.display_text
        Fiscal Year | APMON | Start Date | End Date
        FY27 | AP01 | 2026-07-01 | 2026-07-31
      TEXT
    end

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
