# frozen_string_literal: true

require 'test_helper'

module HsaAdoptionCards
  # The procedures are never called here — GSA_Scan is not part of the test
  # environment. The client is stood in for, so what is under test is the
  # SQL that would be sent and what comes back from the rows.
  class ProcedureTest < ActiveSupport::TestCase
    class FakeClient
      attr_reader :sql

      def initialize(rows: [], error: nil)
        @rows = rows
        @error = error
      end

      def execute(sql)
        @sql = sql
        raise @error if @error

        @rows
      end
    end

    # Minitest's stub is not available in this suite, so the class method is
    # swapped by hand and always put back.
    def with_client(client)
      original = Connection.method(:open)
      Connection.define_singleton_method(:open) { |&block| block.call(client) }
      yield client
    ensure
      Connection.define_singleton_method(:open, original)
    end

    test 'only mapped keys reach the procedure, blank ones are left out, and the user always travels' do
      client = FakeClient.new
      with_client(client) do
        CardSearch.call({ 'lastName' => 'Cross', 'firstName' => '', 'dobYear' => nil, 'bogus' => 'DROP TABLE' },
                        app_user: 'jane@example.com')
      end

      assert_equal "EXEC dbo.HSA_Adopt_usp_SearchCards @LastName = N'Cross', @AppUser = N'jane@example.com'", client.sql
    end

    test 'values are bound, not interpolated' do
      client = FakeClient.new
      with_client(client) do
        CardSearch.call({ 'lastName' => "O'Brien" }, app_user: 'jane@example.com')
      end

      assert_includes client.sql, "@LastName = N'O''Brien'"
    end

    test 'a search with no criteria is refused before any SQL is sent' do
      client = FakeClient.new
      with_client(client) do
        assert_raises(Error) { CardSearch.call({ 'fuzzy' => 1, 'reason' => 'RR-1' }, app_user: 'jane@example.com') }
      end
      assert_nil client.sql
    end

    test 'browse maps its own parameters' do
      client = FakeClient.new
      with_client(client) do
        CardBrowse.call({ 'sortBy' => 'Case_Number', 'sortDir' => 'DESC', 'page' => 2, 'pageSize' => 50, 'status' => 'REVIEW' },
                        app_user: 'jane@example.com')
      end

      assert_equal "EXEC dbo.HSA_Adopt_usp_BrowseCards @GroupStatus = N'REVIEW', @SortBy = N'Case_Number', " \
                   "@SortDir = N'DESC', @Page = 2, @PageSize = 50, @AppUser = N'jane@example.com'", client.sql
    end

    test 'dates come back as ISO strings and the 1900 placeholder as nil' do
      rows = [{ 'ID' => 1, 'Child_DOB' => Date.new(1956, 4, 23), 'CloseDate' => Date.new(1900, 1, 1),
                'FinalDate_FinalDecree' => Time.zone.local(1961, 4, 10, 0, 0, 0), 'Notes' => nil }]
      result = with_client(FakeClient.new(rows: rows)) do
        CardBrowse.call({}, app_user: 'jane@example.com')
      end

      assert_equal({ 'ID' => 1, 'Child_DOB' => '1956-04-23', 'CloseDate' => nil,
                     'FinalDate_FinalDecree' => '1961-04-10', 'Notes' => nil }, result.first)
    end

    test 'a permission refusal from SQL Server is translated into plain language' do
      error = Class.new(StandardError) { def db_error_number = 229 }.new('The EXECUTE permission was denied')

      raised = with_client(FakeClient.new(error: error)) do
        assert_raises(AccessDenied) { CardBrowse.call({}, app_user: 'jane@example.com') }
      end

      assert_match(/HSA_Adopt_Searchers/, raised.message)
      assert_match(/EXECUTE permission/, raised.detail)
    end

    test 'any other SQL failure is passed through verbatim' do
      error = StandardError.new('Could not find stored procedure')
      raised = with_client(FakeClient.new(error: error)) do
        assert_raises(Error) { CardBrowse.call({}, app_user: 'jane@example.com') }
      end

      assert_match(/Could not find stored procedure/, raised.message)
      refute_kind_of AccessDenied, raised
    end
  end
end
