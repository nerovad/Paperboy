# frozen_string_literal: true

require 'test_helper'

module Billing
  class CostAnalysisTest < ActiveSupport::TestCase
    FakePeriod = Data.define(:start_date, :end_date)

    test 'returns the amount and cost variance for the active period' do
      rows = ActiveRecord::Result.new(
        %w[amount_cost_variance],
        [['-25.50']]
      )
      connection = Minitest::Mock.new
      connection.expect(:exec_query, rows) do |sql|
        assert_includes sql, 'T.[AMOUNT]'
        assert_includes sql, 'T.[COST]'
        refute_includes sql, 'T.[QUANTITY]'
        refute_includes sql, 'T.[RATE]'
        assert_includes sql, "'2026-07-01'"
        assert_includes sql, "'2026-07-31'"
        assert_includes sql, 'fnTC60PostingRef(T.[TYPE]'
        true
      end

      result = CostAnalysis.new(period, connection: connection).result

      assert_equal BigDecimal('-25.50'), result.amount_cost_variance
      connection.verify
    end

    test 'returns rows whose amount differs from cost' do
      rows = ActiveRecord::Result.new(%w[AMOUNT COST], [['10.00', '9.00']])
      connection = Minitest::Mock.new
      connection.expect(:exec_query, rows) do |sql|
        assert_includes sql, 'COALESCE(T.[AMOUNT], 0) <> COALESCE(T.[COST], 0)'
        true
      end

      result = CostAnalysis.new(period, connection: connection).error_rows(:amount_vs_cost).first

      assert result.cells.all?(&:invalid)
      connection.verify
    end

    private

    def period
      FakePeriod.new(start_date: Date.new(2026, 7, 1), end_date: Date.new(2026, 7, 31))
    end
  end
end
