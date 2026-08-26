# frozen_string_literal: true

require 'test_helper'

module P2m
  class DateRangeTest < ActiveSupport::TestCase
    Period = Data.define(:start_date, :end_date)

    class TestController < ActionController::Base
      include DateRange

      def date_range_param_key
        :date_range
      end

      public :set_dates
    end

    test 'defaults to the active billing period' do
      period = Period.new(Date.new(2026, 8, 1), Date.new(2026, 8, 31))

      Billing::ActiveBillingPeriod.stub(:current, period) do
        controller = build_controller
        controller.set_dates

        assert_equal period.start_date, controller.instance_variable_get(:@start_date)
        assert_equal period.end_date, controller.instance_variable_get(:@end_date)
      end
    end

    test 'uses dates selected by the user' do
      period = Period.new(Date.new(2026, 8, 1), Date.new(2026, 8, 31))
      params = { date_range: { start_date: '2026-07-10', end_date: '2026-09-05' } }

      Billing::ActiveBillingPeriod.stub(:current, period) do
        controller = build_controller(params)
        controller.set_dates

        assert_equal Date.new(2026, 7, 10), controller.instance_variable_get(:@start_date)
        assert_equal Date.new(2026, 9, 5), controller.instance_variable_get(:@end_date)
      end
    end

    test 'defaults to today when there is no active billing period' do
      Billing::ActiveBillingPeriod.stub(:current, nil) do
        controller = build_controller
        controller.set_dates

        assert_equal Date.current, controller.instance_variable_get(:@start_date)
        assert_equal Date.current, controller.instance_variable_get(:@end_date)
      end
    end

    private

    def build_controller(params = {})
      TestController.new.tap do |controller|
        controller.params = ActionController::Parameters.new(params)
      end
    end
  end
end
