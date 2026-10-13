# frozen_string_literal: true

require 'test_helper'

module SqlDashboards
  class RunnerTest < ActiveSupport::TestCase
    include TestAccess

    TEN_ROWS = 'SELECT n FROM (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10)) AS v(n) ORDER BY n'
    ACTOR = SessionUser.new(employee_id: 102_989, email: 'maria.acosta@example.com',
                            first_name: 'Maria', last_name: 'Acosta')

    def run_sql(statement, **attributes)
      query = Query.new({ name: 'Scratch', database_key: 'paperboy', chart_type: 'table',
                          statement: statement }.merge(attributes))
      with_read_only_login { Runner.new(query, actor: ACTOR).call }
    end

    # A pool whose connection fails the way SQL Server would.
    def failing_with(error)
      pool = Object.new
      pool.define_singleton_method(:with_connection) { |&_block| raise error }
      database = Database.new('paperboy')
      database.define_singleton_method(:pool) { pool }
      database
    end

    test 'returns the columns and rows of a select' do
      result = run_sql("SELECT 'Open' AS status, 4 AS total UNION ALL SELECT 'Closed', 2")

      assert_predicate result, :ok?
      assert_equal %w[status total], result.columns
      assert_equal [['Open', 4], ['Closed', 2]], result.rows
      assert_not result.truncated
      assert_kind_of Integer, result.duration_ms
    end

    test 'keeps the first rows up to the cap and says there were more' do
      result = Database.stub(:row_limit, 3) { run_sql(TEN_ROWS) }

      assert_equal [[1], [2], [3]], result.rows
      assert result.truncated
    end

    test 'a result of exactly the cap is not called truncated' do
      result = Database.stub(:row_limit, 10) { run_sql(TEN_ROWS) }

      assert_equal 10, result.rows.size
      assert_not result.truncated
    end

    test 'the cap does not stay on the connection' do
      Database.stub(:row_limit, 3) { run_sql(TEN_ROWS) }

      assert_equal 10, ApplicationRecord.connection.select_all(TEN_ROWS).rows.size
    end

    test 'the cap comes off after SQL that fails' do
      result = Database.stub(:row_limit, 3) { run_sql('SELECT * FROM no_such_table_here') }

      assert_not result.ok?
      assert_equal 10, ApplicationRecord.connection.select_all(TEN_ROWS).rows.size
    end

    test 'bad SQL comes back as a message, not an exception' do
      result = run_sql('SELECT * FROM no_such_table_here')

      assert_not result.ok?
      assert_match(/no_such_table_here/, result.error)
      assert_no_match(/TinyTds::Error/, result.error)
      assert_empty result.rows
    end

    test 'a write the database refuses is reported in its own words' do
      refused = ActiveRecord::StatementInvalid.new(
        "TinyTds::Error: The UPDATE permission was denied on the object 'form_templates'."
      )
      result = Database.stub(:find, failing_with(refused)) { run_sql("UPDATE form_templates SET name = 'x'") }

      assert_equal "The UPDATE permission was denied on the object 'form_templates'.", result.error
    end

    test 'a query that runs past the timeout is reported as cancelled' do
      timeout = ActiveRecord::StatementTimeout.new('Adaptive Server connection timed out')
      result = Database.stub(:timeout, 30) do
        Database.stub(:find, failing_with(timeout)) { run_sql("WAITFOR DELAY '00:01:00'") }
      end

      assert_equal 'The query ran longer than 30 seconds and was cancelled.', result.error
    end

    test 'nothing runs without the read-only login' do
      query = Query.new(name: 'Scratch', database_key: 'paperboy', chart_type: 'table', statement: 'SELECT 1 AS n')
      result = Database.stub(:configured?, false) { Runner.new(query, actor: ACTOR).call }

      assert_equal 'SQL Dashboards has no read-only login on this server.', result.error
    end

    test 'a statement with no result set says so' do
      assert_equal 'The statement returned no result set.', run_sql('DECLARE @n int').error
    end

    test 'blank SQL and an unknown database are refused before anything runs' do
      assert_equal 'Write some SQL to run.', run_sql('  ').error
      assert_equal 'Choose a database.', run_sql('SELECT 1 AS n', database_key: 'billing').error
    end

    test 'every run is logged with who ran what and how it went' do
      saved = build_query(statement: TEN_ROWS)

      assert_difference 'Event.count', 2 do
        with_read_only_login { Runner.new(saved, actor: ACTOR).call }
        run_sql('SELECT * FROM no_such_table_here')
      end

      good, bad = Event.order(:id).last(2)
      assert_equal ['run', saved.id, 'Requests by status', '102989', 'Maria Acosta', 'paperboy', TEN_ROWS, 10],
                   [good.action, good.sql_dashboard_query_id, good.query_name, good.employee_id,
                    good.employee_name, good.database_key, good.statement, good.row_count]
      assert_nil good.error_message
      assert_nil bad.sql_dashboard_query_id
      assert_match(/no_such_table_here/, bad.error_message)
    end
  end
end
