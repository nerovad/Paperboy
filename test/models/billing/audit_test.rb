# frozen_string_literal: true

require 'test_helper'

module Billing
  class AuditTest < ActiveSupport::TestCase
    FakePeriod = Data.define(:start_date, :end_date)

    test 'returns every audit check grouped for display' do
      rows = ActiveRecord::Result.new(
        %w[audit_key failure_count],
        [%w[cunit 3], %w[service 2]]
      )
      connection = Minitest::Mock.new
      connection.expect(:exec_query, rows, [String])

      groups = Audit.new(period, connection: connection).results
      customer_results = groups.fetch(groups.keys.first)
      service_provider_results = groups.fetch(groups.keys.last)

      assert_equal %i[customer service_provider], groups.keys.map(&:key)
      assert_equal 3, customer_results.first.count
      assert_equal 0, customer_results.second.count
      assert_equal 2, service_provider_results.first.count
      connection.verify
    end

    test 'queries all definitions using the active period' do
      connection = Minitest::Mock.new
      connection.expect(:exec_query, ActiveRecord::Result.empty) do |sql|
        assert_equal 10, sql.scan('SELECT ').length - sql.scan('SELECT 1').length
        assert_includes sql, "'2026-07-01'"
        assert_includes sql, "'2026-07-31'"
        assert_includes sql, 'GSABSS.dbo.tc60_services'
        true
      end

      Audit.new(period, connection: connection).results

      connection.verify
    end

    private

    def period
      FakePeriod.new(start_date: Date.new(2026, 7, 1), end_date: Date.new(2026, 7, 31))
    end
  end
end
