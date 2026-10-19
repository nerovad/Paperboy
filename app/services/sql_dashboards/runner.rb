# frozen_string_literal: true

module SqlDashboards
  # Runs a query's SQL on its read-only connection and logs the run.
  #
  # It never raises for something the SQL did. A syntax error, a refused
  # write, a timeout and a missing login all come back as a Result carrying
  # the message, so a screen can show it where the chart would have been.
  class Runner
    Result = Struct.new(:columns, :rows, :truncated, :duration_ms, :error, keyword_init: true) do
      def ok? = error.nil?
    end

    def initialize(query, actor:)
      @query = query
      @actor = actor
    end

    def call
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = run
      result.duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      log(result)
      result
    end

    private

    attr_reader :query, :actor

    def run
      return failure('Choose a database.') unless query.database
      return failure('Write some SQL to run.') if query.statement.blank?

      rows_from(query.database.pool.with_connection { |connection| fetch(connection) })
    rescue Database::NotConfigured => e
      failure(e.message)
    rescue ActiveRecord::StatementTimeout
      failure("The query ran longer than #{Database.timeout} seconds and was cancelled.")
    rescue ActiveRecord::ActiveRecordError, TinyTds::Error => e
      failure(e.message.sub(/\A(TinyTds::Error: )+/, ''))
    end

    # SET ROWCOUNT makes SQL Server stop sending once the cap is passed, so a
    # careless SELECT * is never read into memory whole. One row past the cap
    # is asked for to tell "exactly the cap" from "more than the cap".
    def fetch(connection)
      connection.execute("SET ROWCOUNT #{row_limit + 1}")
      connection.select_all(query.statement, 'SQL Dashboards')
    ensure
      reset(connection)
    end

    # The connection goes back to the pool for the next query, so the cap
    # must not stay on it. One that will not answer is dropped instead.
    def reset(connection)
      connection.execute('SET ROWCOUNT 0')
    rescue ActiveRecord::ActiveRecordError, TinyTds::Error
      connection.disconnect!
    end

    def rows_from(fetched)
      return failure('The statement returned no result set.') if fetched.columns.empty?

      Result.new(columns: fetched.columns, rows: fetched.rows.first(row_limit),
                 truncated: fetched.rows.size > row_limit)
    end

    def failure(message)
      Result.new(columns: [], rows: [], truncated: false, error: message)
    end

    def row_limit = Database.row_limit

    def log(result)
      Event.record('run', actor: actor, query: query, duration_ms: result.duration_ms,
                          row_count: result.rows.size, error_message: result.error)
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.error("SQL Dashboards could not log a run: #{e.message}")
    end
  end
end
