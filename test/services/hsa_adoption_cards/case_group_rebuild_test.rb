# frozen_string_literal: true

require 'test_helper'

module HsaAdoptionCards
  class CaseGroupRebuildTest < ActiveSupport::TestCase
    class FakeClient
      attr_reader :sql

      def initialize(rows: [])
        @rows = rows
      end

      def execute(sql)
        @sql = sql
        @rows
      end
    end

    def with_client(client)
      original = Connection.method(:open)
      Connection.define_singleton_method(:open) { |&block| block.call(client) }
      yield client
    ensure
      Connection.define_singleton_method(:open, original)
    end

    COUNTS = [{ 'Status' => 'AUTO', 'Groups' => 4 }, { 'Status' => 'REVIEW', 'Groups' => 1 }].freeze

    test 'runs the procedure with the default margin and no app user' do
      client = FakeClient.new(rows: COUNTS)
      result = with_client(client) { CaseGroupRebuild.call }

      assert_equal 'EXEC dbo.HSA_Adopt_usp_RebuildCaseGroups @AmbiguityMargin = 5', client.sql
      assert_equal 5, result.margin
      assert_equal({ 'AUTO' => 4, 'REVIEW' => 1 }, result.counts)
      assert_equal 5, result.total
    end

    test 'a margin given as text from the form is bound as a number' do
      client = FakeClient.new(rows: COUNTS)
      result = with_client(client) { CaseGroupRebuild.call(margin: ' 12 ') }

      assert_equal 'EXEC dbo.HSA_Adopt_usp_RebuildCaseGroups @AmbiguityMargin = 12', client.sql
      assert_equal 12, result.margin
    end

    test 'a blank margin falls back to the default' do
      client = FakeClient.new(rows: [])
      result = with_client(client) { CaseGroupRebuild.call(margin: '') }

      assert_equal 5, result.margin
      assert_equal 0, result.total
    end

    test 'a margin outside the range is refused before any SQL is sent' do
      client = FakeClient.new
      with_client(client) do
        assert_raises(Error) { CaseGroupRebuild.call(margin: '101') }
        assert_raises(Error) { CaseGroupRebuild.call(margin: '-1') }
        assert_raises(Error) { CaseGroupRebuild.call(margin: 'five') }
      end
      assert_nil client.sql
    end
  end
end
