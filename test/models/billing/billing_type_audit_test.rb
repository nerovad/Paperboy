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
      rows = ActiveRecord::Result.new(%w[billing_type row_count error_count], [['GPH', 7, 2]])
      connection = Minitest::Mock.new
      connection.expect(:exec_query, rows) do |sql|
        assert_includes sql, 'SUM(Audited.is_error)'
        assert_includes sql, 'FROM ( SELECT T.[TYPE]'
        assert_includes sql, "N'GPH'"
        refute_includes sql, 'OFF'
        assert_includes sql, "'2026-07-01'"
        true
      end

      results = BillingTypeAudit.new(period, types: types, connection: connection).results

      assert_equal ['GPH'], results.map(&:code)
      assert_equal [7], results.map(&:row_count)
      assert_equal [2], results.map(&:error_count)
      connection.verify
    end

    test 'does not query TC60 when no Billing types are active' do
      type = FakeType.new(code: 'OFF', name: 'Disabled', active: false)
      connection = Minitest::Mock.new

      assert_empty BillingTypeAudit.new(period, types: [type], connection: connection).results
      connection.verify
    end

    test 'loads TC60 error rows for an active type' do
      columns = %w[TYPE CUNIT audit_error_cunit audit_error_cobject audit_error_cactivity
                   audit_error_cfunction audit_error_cprogram audit_error_cphase audit_error_ctask
                   audit_error_service audit_error_sactivity audit_error_sfunction]
      values = %w[GPH BAD 1 0 0 0 0 0 0 0 0 0]
      rows = ActiveRecord::Result.new(columns, [values])
      connection = Minitest::Mock.new
      connection.expect(:exec_query, rows) do |sql|
        assert_includes sql, 'SELECT T.*'
        assert_includes sql, "T.[TYPE] = N'GPH'"
        assert_includes sql, 'GSABSS.dbo.units'
        assert_includes sql, 'GSABSS.dbo.tc60_services'
        true
      end

      audit = BillingTypeAudit.new(period, types: [], connection: connection)

      result = audit.error_rows('GPH').first

      assert_equal({ 'TYPE' => 'GPH', 'CUNIT' => 'BAD' }, result.attributes)
      assert result.cells.find { |cell| cell.column == 'CUNIT' }.invalid
      connection.verify
    end

    private

    def period
      FakePeriod.new(start_date: Date.new(2026, 7, 1), end_date: Date.new(2026, 7, 31))
    end
  end
end
