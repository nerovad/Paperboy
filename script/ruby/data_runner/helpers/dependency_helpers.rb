# frozen_string_literal: true

require_relative '../db/mssql_helpers'
require_relative '../log/data_runner_logger'

module DataRunnerDependencyHelpers
  module_function

  DEFAULT_TIMEOUT_SECONDS = 3600
  DEFAULT_POLL_SECONDS = 1

  def wait!(name, config)
    dependency = config[:dependency]
    return if dependency.nil?

    run_id = ENV.fetch('DATARUNNER_RUN_ID', '').strip
    raise "#{name}: dependency #{dependency} requires DATARUNNER_RUN_ID" if run_id.empty?

    ensure_scheduled!(name, dependency)
    client = log_client
    wait_for_log!(client, name, dependency, run_id)
  ensure
    client&.close
  end

  def wait_for_log!(client, name, dependency, run_id)
    deadline = monotonic_time + timeout_seconds

    loop do
      row = latest_dependency_log(client, dependency, run_id)
      return puts("[OK] #{name}: dependency #{dependency} injection succeeded") if injection_succeeded?(row)

      raise "#{name}: dependency #{dependency} failed" if failed?(row)
      raise "#{name}: timed out waiting for dependency #{dependency}" if monotonic_time >= deadline

      sleep poll_seconds
    end
  end

  def latest_dependency_log(client, dependency, run_id)
    sql = <<~SQL
      SELECT TOP (1) [script], [status]
      FROM [#{DataRunnerLogger::LOG_SCHEMA}].[#{DataRunnerLogger::LOG_TABLE}]
      WHERE [run_id] = N'#{client.escape(run_id)}'
        AND [selector] = N'#{client.escape(dependency)}'
      ORDER BY [completed_at] DESC
    SQL
    client.execute(sql).first
  end

  def injection_succeeded?(row)
    value(row, 'status') == 'succeeded' && File.basename(value(row, 'script').to_s) == 'inject.rb'
  end

  def failed?(row)
    value(row, 'status') == 'failed'
  end

  def value(row, key)
    return if row.nil?

    row[key] || row[key.to_sym]
  end

  def ensure_scheduled!(name, dependency)
    scheduled = ENV.fetch('DATARUNNER_RUN_DSLS', '').split(',')
    return if scheduled.include?(dependency)

    raise "#{name}: dependency #{dependency} is not scheduled in this run"
  end

  def log_client
    MssqlHelpers.load_dotenv!
    host = ENV.fetch('DATARUNNER_LOG_HOST', '').strip
    host = MssqlHelpers.env_any('MSSQL_HOST', 'GSABSS_HOST') if host.empty?
    host = 'GSASQL16' if host.to_s.strip.empty?
    MssqlHelpers.connect!(host, database: DataRunnerLogger::LOG_DATABASE)
  end

  def timeout_seconds
    ENV.fetch('DATARUNNER_DEPENDENCY_TIMEOUT', DEFAULT_TIMEOUT_SECONDS).to_f
  end

  def poll_seconds
    ENV.fetch('DATARUNNER_DEPENDENCY_POLL_INTERVAL', DEFAULT_POLL_SECONDS).to_f
  end

  def monotonic_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
