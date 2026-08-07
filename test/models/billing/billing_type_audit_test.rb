# frozen_string_literal: true

require 'test_helper'

module Billing
  class BillingTypeAuditTest < ActiveSupport::TestCase
    FakePeriod = Data.define(:start_date, :end_date)
    FakeType = Data.define(:code, :name, :active) do
      alias_method :active?, :active
    end

    test 'returns counts for active Billing types only' do
      types = [
        FakeType.new(code: 'GPH', name: 'Graphics', active: true),
        FakeType.new(code: 'OFF', name: 'Disabled', active: false)
      ]
      rows = ActiveRecord::Result.new(%w[billing_type row_count], [['GPH', 7]])
      connection = Minitest::Mock.new
      connection.expect(:exec_query, rows) do |sql|
        assert_includes sql, "N'GPH'"
        refute_includes sql, 'OFF'
        assert_includes sql, "'2026-07-01'"
        true
      end

      results = BillingTypeAudit.new(period, types: types, connection: connection).results

      assert_equal ['GPH'], results.map(&:code)
      assert_equal [7], results.map(&:count)
      connection.verify
    end

    test 'does not query TC60 when no Billing types are active' do
      type = FakeType.new(code: 'OFF', name: 'Disabled', active: false)
      connection = Minitest::Mock.new

      assert_empty BillingTypeAudit.new(period, types: [type], connection: connection).results
      connection.verify
    end

    private

    def period
      FakePeriod.new(start_date: Date.new(2026, 7, 1), end_date: Date.new(2026, 7, 31))
    end
  end
end
