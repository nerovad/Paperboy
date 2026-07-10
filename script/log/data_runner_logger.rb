# frozen_string_literal: true

require 'etc'
require 'securerandom'
require 'socket'
require 'time'
require_relative '../db/mssql_helpers'

# Database-backed command logger for DataRunner Rake stage executions.
module DataRunnerLogger
  module_function

  LOG_DATABASE = 'GSABSS'
  LOG_SCHEMA = 'dbo'
  LOG_TABLE = 'DataRunner_Log'
  RUN_ID = SecureRandom.uuid

  def log_command(command:, script:, args:, started_at:, completed_at:, success:, exit_status:, options: {})
    return if disabled?

    MssqlHelpers.load_dotenv!

    host = ENV.fetch('DATARUNNER_LOG_HOST', nil).to_s.strip
    host = MssqlHelpers.env_any('MSSQL_HOST', 'GSABSS_HOST') if host.empty?
    host = 'GSASQL16' if host.to_s.strip.empty?

    payload = {
      command: command,
      script: script,
      args: args,
      started_at: started_at,
      completed_at: completed_at,
      success: success,
      exit_status: exit_status,
      error: options[:error]
    }

    client = MssqlHelpers.connect!(host, database: LOG_DATABASE)
    selectors(args, options[:selectors] || options[:selector]).each do |log_selector|
      client.execute(insert_sql(client, payload.merge(selector: log_selector))).do
    end
  rescue StandardError => e
    warn "[WARN] DataRunner log write failed: #{e.class}: #{e.message}"
  ensure
    client&.close
  end

  def disabled?
    %w[1 true yes y on].include?(ENV.fetch('DATARUNNER_LOG_DISABLED', '').strip.downcase)
  end

  def insert_sql(client, payload)
    duration_ms = ((payload.fetch(:completed_at) - payload.fetch(:started_at)) * 1000).round
    args = payload.fetch(:args)
    error = payload[:error]
    values = {
      run_id: RUN_ID,
      command: payload.fetch(:command),
      script: payload.fetch(:script),
      arguments: args.join(' '),
      selector: payload[:selector],
      status: payload.fetch(:success) ? 'succeeded' : 'failed',
      exit_status: payload[:exit_status],
      started_at: sql_time(payload.fetch(:started_at)),
      completed_at: sql_time(payload.fetch(:completed_at)),
      duration_ms: duration_ms,
      cwd: Dir.pwd,
      host_name: Socket.gethostname,
      os_user: Etc.getlogin || ENV.fetch('USER', nil),
      process_id: Process.pid,
      git_sha: git_sha,
      error_class: error&.class&.name,
      error_message: error&.message
    }

    columns = values.keys.map(&:to_s)
    literals = values.values.map { |value| sql_literal(client, value) }

    "INSERT INTO #{MssqlHelpers.sql_qualified(LOG_SCHEMA, LOG_TABLE)} " \
      "(#{columns.map { |column| MssqlHelpers.quote_ident(column) }.join(', ')}) " \
      "VALUES (#{literals.join(', ')})"
  end

  def selectors(args, implied_selectors = nil)
    implied = Array(implied_selectors).compact.map(&:to_s).reject(&:empty?)
    return implied unless implied.empty?

    explicit_selector = selector(args)
    return [ explicit_selector ] if explicit_selector

    [ nil ]
  end

  def selector(args)
    args.compact.map(&:to_s).reject(&:empty?).first
  end

  def sql_time(time)
    time.utc.strftime('%Y-%m-%dT%H:%M:%S.%6N')
  end

  def sql_literal(client, value)
    return 'NULL' if value.nil?

    case value
    when Integer
      value.to_s
    else
      "N'#{client.escape(value.to_s)}'"
    end
  end

  def git_sha
    @git_sha ||= begin
      sha = `git rev-parse --verify HEAD 2>/dev/null`.strip
      sha.empty? ? nil : sha
    end
  end
end
