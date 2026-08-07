# frozen_string_literal: true

require 'test_helper'

module Billing
  class AuditRowsTest < ActiveSupport::TestCase
    FakePeriod = Data.define(:start_date, :end_date)

    test 'loads period rows for the selected invalid value' do
      rows = ActiveRecord::Result.new(%w[ID CUNIT], [[12, 'BAD001']])
      connection = Minitest::Mock.new
      connection.expect(:exec_query, rows) do |sql|
        assert_includes sql, 'SELECT T.*'
        assert_includes sql, 'LTRIM(RTRIM(T.CUNIT)) = N\'BAD001\''
        assert_includes sql, "'2026-07-01'"
        true
      end

      results = AuditRows.new(period, Audit.find_check(:cunit), 'BAD001', connection: connection).results

      assert_equal [{ 'ID' => 12, 'CUNIT' => 'BAD001' }], results
      connection.verify
    end

    private

    def period
      FakePeriod.new(start_date: Date.new(2026, 7, 1), end_date: Date.new(2026, 7, 31))
    end
  end
end
