# frozen_string_literal: true

require 'test_helper'

module Billing
  class DashboardTest < ActiveSupport::TestCase
    test 'lists the Billing dashboards in display order' do
      dashboards = Dashboard.all

      assert_equal ['Billing Summary', 'Billing Trends'], dashboards.map(&:name)
      assert_equal %w[summary trends], dashboards.map(&:key)
    end

    test 'reads each dashboard id from its environment setting' do
      original_id = ENV.fetch('BILLING_SUMMARY_DASHBOARD_ID', nil)
      ENV['BILLING_SUMMARY_DASHBOARD_ID'] = '42'

      dashboard = Dashboard.all.first

      assert dashboard.configured?
      assert_equal '42', dashboard.dashboard_id
    ensure
      ENV['BILLING_SUMMARY_DASHBOARD_ID'] = original_id
    end
  end
end
