# frozen_string_literal: true

require 'test_helper'

module P2m
  class BillingUploadDslTest < ActiveSupport::TestCase
    test 'uploads the billing datasets into GSAP2M' do
      expected = {
        'companions' => %w[Companion OMSNumber],
        'dailypresorts' => %w[DailyPresort omsnumber],
        'moveresults' => %w[MoveResults OMSNumber]
      }

      expected.each do |slug, (table, key)|
        connection = DslCatalog.find!(slug).config.fetch(:database_connections).first

        assert_equal 'GSAP2M', connection[:database]
        assert_equal 'dbo', connection[:schema]
        assert_equal table, connection[:table]
        assert_equal :append, connection.dig(:inject, :mode)
        assert_equal [key], connection.dig(:inject, :reject_existing)
      end
    end

    test 'detects an import from the GSAP2M production tables' do
      queries = []
      connection = Object.new
      connection.define_singleton_method(:quote) { |value| "'#{value}'" }
      connection.define_singleton_method(:quote_column_name) { |name| "[#{name}]" }
      connection.define_singleton_method(:quote_table_name) { |name| name }
      connection.define_singleton_method(:select_value) do |sql|
        queries << sql
        sql.include?('COUNT') ? 1 : Time.utc(2026, 10, 16)
      end
      ledger = OmsUploadLedger.new(staging_path: Dir.tmpdir, processed_path: Dir.tmpdir)

      found = OmsUpload.stub(:connection, connection) do
        ledger.send(:imported_dataset_at, '53522219')
      end

      sql = queries.join("\n")
      assert_equal Time.utc(2026, 10, 16), found
      assert_includes sql, 'GSAP2M.dbo.Companion'
      assert_includes sql, 'GSAP2M.dbo.DailyPresort'
      assert_includes sql, 'GSAP2M.dbo.MoveResults'
      assert_includes sql, '[OMSNumber]'
      assert_includes sql, '[omsnumber]'
      refute_includes sql, 'GSABSS'
    end
  end
end
