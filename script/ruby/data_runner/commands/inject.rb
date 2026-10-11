#!/usr/bin/env ruby
# frozen_string_literal: true

# inject.rb

# {{{ Requirements and definitions.
#
# Loads output/data_runner/05_DSL_Applied/*.csv into SQL Server with bcp.
# bcp runs on this host. A staging table takes the load, and a short
# transaction publishes it, so a failed bcp leaves the live rows in place.
#
# Modes:
# - :truncate_insert : TRUNCATE + INSERT all rows
# - :append          : INSERT all rows
# - :delete_insert   : DELETE (database_connections entry inject.delete_where) + INSERT all rows
#
# Connection is configured via ENV:
#   MSSQL_HOST      (required default host) e.g. "gsasql16" or "gsasql16.ent.co.ventura.gsa"
#   MSSQL_PORT      (optional)  default 1433
#   MSSQL_USERNAME  (required for SQL auth)
#   MSSQL_PASSWORD  (required for SQL auth)
#   MSSQL_TDSVER    (optional)  default "7.4"
#   MSSQL_ENCRYPT   (optional)  "true"/"false" (TinyTDS supports :encrypt on newer stacks)
#   BCP_EXECUTABLE  (optional)  default "bcp"

require 'rbconfig'
require_relative 'dsl_map'
require_relative '../helpers/bcp_character_file'
require_relative '../helpers/bcp_load'
require_relative '../helpers/bcp_stage'
require_relative '../helpers/etl_helpers'
require_relative '../helpers/etl_mapping_helpers'
require_relative '../helpers/dependency_helpers'
require_relative '../db/mssql_helpers'
require_relative '../constants/workflow'
require_relative '../constants/workflow_paths'

ROOT = File.expand_path('../../../..', __dir__)
$LOAD_PATH.unshift(ROOT)

APPLIED_DIR = WorkflowPaths::APPLIED_DIR

# -------------------------------------------------------------------------- }}}
def column_type_map(cfg)
  EtlMappingHelpers.output_columns(cfg).to_h { |column| [column[:name], column[:data_type]] }
end

def identity_insert_sql(schema, table, enabled)
  state = enabled ? 'ON' : 'OFF'
  "SET IDENTITY_INSERT #{MssqlHelpers.sql_qualified(schema, table)} #{state}"
end

def needs_identity_insert?(cfg, columns)
  identity_columns = EtlMappingHelpers.csv_mapping(cfg)
                                      .select { |entry| entry[:identity] }
                                      .map { |entry| entry[:output] }
  !!identity_columns.intersect?(columns)
end

# -------------------------------------------------------------------------- }}}
# {{{ Helper: delete_sql

def delete_sql(schema, table, where_sql)
  "DELETE FROM #{MssqlHelpers.sql_qualified(schema, table)} WHERE #{where_sql}"
end

# -------------------------------------------------------------------------- }}}
# {{{ Helper: delete_where

def delete_where(cfg, database_connection = nil)
  w = inject_cfg(cfg, database_connection)[:delete_where]
  w.to_s.strip
end

def reject_existing_columns(cfg, database_connection = nil)
  Array(inject_cfg(cfg, database_connection)[:reject_existing]).map(&:to_s)
end

def existing_row_sql(client, schema, table, columns, row, column_types)
  predicates = columns.map do |column|
    existing_predicate(client, column, row[column], column_types[column])
  end
  "SELECT TOP 1 1 FROM #{MssqlHelpers.sql_qualified(schema, table)} WHERE #{predicates.join(' AND ')}"
end

def existing_predicate(client, column, value, data_type)
  quoted = MssqlHelpers.quote_ident(column)
  text = value.nil? ? '' : value.to_s
  if SqlValue.blank_becomes_null?(data_type)
    return "#{quoted} IS NULL" if text.strip.empty?

    literal = "N'#{client.escape(text)}'"
    return "#{quoted} = CONVERT(#{DataRunner::BcpStage.sql_type(data_type)}, #{literal})"
  end
  return "#{quoted} IS NULL" if value.nil?

  "#{quoted} = N'#{client.escape(text)}'"
end

def reject_existing!(client, target, columns, row, column_types)
  return if columns.empty?

  missing = columns - row.keys.map(&:to_s)
  raise "duplicate key columns missing from the applied file: #{missing.join(', ')}" if missing.any?

  sql = existing_row_sql(client, target.schema, target.table, columns, row, column_types)
  exists = client.execute(sql).each.any?
  return unless exists

  identity = columns.map { |column| "#{column}=#{row[column]}" }.join(', ')
  raise "job already imported: #{identity}"
end

def inject_timing(name, duplicate_check_seconds, insert_seconds, rows_per_second)
  parts = []
  parts << format('duplicate check %.3fs', duplicate_check_seconds) if duplicate_check_seconds
  parts << format('insert %.3fs', insert_seconds)
  format('[TIMING] %s: %s; %.0f rows/s', name, parts.join('; '), rows_per_second)
end

# -------------------------------------------------------------------------- }}}
# {{{ Helper: inject_cfg

def inject_cfg(cfg, database_connection = nil)
  dbc = database_connection || cfg[:database_connection] || {}
  dbc[:inject] || cfg[:inject] || {}
end

# -------------------------------------------------------------------------- }}}
# {{{ Helper: inject_mode

def inject_mode(cfg, database_connection = nil)
  m = inject_cfg(cfg, database_connection)[:mode]
  (m || :truncate_insert).to_sym
end

# -------------------------------------------------------------------------- }}}
# {{{ Helper: post inject scripts

def post_inject_script_config(inject)
  raw = inject[:post_script] || inject[:post_inject_script] || inject[:script] || inject[:command]
  return nil if raw.nil?

  case raw
  when Hash
    path = raw[:path] || raw[:file]
    args = raw[:args] || []
  else
    path = raw
    args = inject[:args] || inject[:script_args] || []
  end

  [path.to_s.strip, Array(args).map(&:to_s)]
end

def post_inject_script_path(script_path)
  root = ROOT
  full_path = File.expand_path(script_path, root)

  raise "post inject script must be inside #{root}" unless full_path == root || full_path.start_with?("#{root}#{File::SEPARATOR}")

  raise "post inject script missing #{full_path}" unless File.file?(full_path)

  full_path
end

def run_post_inject_script(name, target, mode, input, inserted, inject)
  config = post_inject_script_config(inject)
  return if config.nil?

  script_path, args = config
  raise 'post inject script requires inject.post_script.path' if script_path.empty?

  full_path = post_inject_script_path(script_path)
  env = {
    'DATARUNNER_DATASET' => name.to_s,
    'DATARUNNER_APPLIED_CSV' => input.to_s,
    'DATARUNNER_TARGET_HOST' => target.host.to_s,
    'DATARUNNER_TARGET_DATABASE' => target.database.to_s,
    'DATARUNNER_TARGET_SCHEMA' => target.schema.to_s,
    'DATARUNNER_TARGET_TABLE' => target.table.to_s,
    'DATARUNNER_INJECT_MODE' => mode.to_s,
    'DATARUNNER_INSERTED_ROWS' => inserted.to_s
  }

  puts "[POST_SCRIPT] #{name}: ruby #{script_path} #{args.join(' ')}"
  return if system(env, RbConfig.ruby, full_path, *args)

  raise "post inject script failed #{script_path}"
end

# -------------------------------------------------------------------------- }}}
# {{{ Helper: truncate_sql

def truncate_sql(schema, table)
  "TRUNCATE TABLE #{MssqlHelpers.sql_qualified(schema, table)}"
end

def acquire_atomic_inject_lock!(client)
  sql = <<~SQL
    DECLARE @result int;
    EXEC @result = sys.sp_getapplock
      @Resource = N'Paperboy.DataRunner.AtomicInject',
      @LockMode = N'Exclusive',
      @LockOwner = N'Transaction',
      @LockTimeout = 600000;
    IF @result < 0 THROW 51000, 'Could not acquire the DataRunner atomic inject lock.', 1;
  SQL
  client.execute(sql).do
end

def import_applied_file(client, target, input, cfg, load)
  header, first_values = BcpCharacterFile.header_and_first_row(input)
  raise "#{input}: missing header row" if header.nil? || header.empty? || header.all?(&:empty?)

  column_types = column_type_map(cfg)
  duplicate_seconds = reject_first_row(client, target, cfg, header, first_values, column_types)
  stage = DataRunner::BcpStage.name_for(target.table)
  record = { host: target.host, database: target.database, schema: target.schema, table: stage }
  load.fetch(:pending_stages) << record
  load_stage!(load.fetch(:name), target, input, record, header)
  inserted = publish_stage!(client, target, stage, header, column_types, load, needs_identity_insert?(cfg, header))
  release_stage(record, load.fetch(:pending_stages)) unless load.fetch(:atomic)
  [inserted, duplicate_seconds]
end

def reject_first_row(client, target, cfg, header, values, column_types)
  columns = reject_existing_columns(cfg, target.connection)
  return nil if columns.empty? || values.nil?

  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  reject_existing!(client, target, columns, header.zip(values).to_h, column_types)
  Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
end

def load_stage!(name, target, input, record, header)
  client = nil
  begin
    client = MssqlHelpers.connect!(target.host)
    client.execute("USE #{MssqlHelpers.quote_ident(target.database)}").do
    DataRunner::BcpStage.create!(client, record[:schema], record[:table], header)
    argv = DataRunner::BcpLoad.command_for(
      host: target.host, database: target.database, schema: record[:schema], table: record[:table], file: input
    )
    puts "[BCP] #{name}: #{DataRunner::BcpLoad.display(argv)}"
    DataRunner::BcpLoad.run!(argv)
  ensure
    client&.close
  end
end

def publish_stage!(client, target, stage, header, column_types, load, identity)
  client.execute('BEGIN TRAN').do unless load.fetch(:atomic)
  apply_inject_mode!(client, target, load.fetch(:mode), load.fetch(:where_sql))
  client.execute(identity_insert_sql(target.schema, target.table, true)).do if identity
  begin
    sql = DataRunner::BcpStage.insert_sql(target.schema, target.table, stage, header, column_types)
    client.execute(sql).do
  ensure
    if identity
      begin
        client.execute(identity_insert_sql(target.schema, target.table, false)).do
      rescue StandardError
        nil
      end
    end
  end
  inserted = staged_count(client, target.schema, stage)
  client.execute('COMMIT TRAN').do unless load.fetch(:atomic)
  inserted
end

def validate_inject_mode!(mode, where_sql)
  case mode
  when :truncate_insert, :append
    nil
  when :delete_insert
    raise 'inject mode :delete_insert requires inject.delete_where' if where_sql.empty?
  else
    raise "unknown inject mode: #{mode.inspect}"
  end
end

def apply_inject_mode!(client, target, mode, where_sql)
  case mode
  when :truncate_insert
    client.execute(truncate_sql(target.schema, target.table)).do
  when :delete_insert
    client.execute(delete_sql(target.schema, target.table, where_sql)).do
  when :append
    nil
  else
    raise "unknown inject mode: #{mode.inspect}"
  end
end

def staged_count(client, schema, table)
  count = 0
  client.execute(DataRunner::BcpStage.count_sql(schema, table)).each do |row|
    count = row.values.first
  end
  Integer(count)
end

def release_stage(record, pending_stages)
  DataRunner::BcpStage.drop_record(record)
  pending_stages.delete(record)
rescue StandardError => e
  warn "[WARN] bcp stage drop failed #{record[:table]}: #{e}"
end

def inject_source(name, cfg, stats)
  unless Workflow.wants_step?(cfg, :inject)
    puts "[SKIP] #{name}: step disabled (:inject)"
    stats.skip!
    return
  end

  csv_name = EtlHelpers.output_for(cfg)
  input = File.join(APPLIED_DIR, csv_name)
  if !File.exist?(input) && EtlHelpers.source_strategy(cfg) == :append
    puts "[SKIP] #{name}: nothing to append (missing #{APPLIED_DIR}/#{csv_name})"
    stats.skip!
    return
  end

  DataRunnerDependencyHelpers.wait!(name, cfg)
  return [csv_name, input] if File.exist?(input)

  puts "[SKIP] #{name}: missing #{APPLIED_DIR}/#{csv_name}"
  stats.fail!
  nil
end

# -------------------------------------------------------------------------- }}}
# {{{ Main logic

puts 'Inject started.'

MssqlHelpers.load_dotenv!

stats = EtlHelpers::RunStats.new

clients = {}
atomic_inject = MssqlHelpers.env_bool('DATARUNNER_ATOMIC_INJECT')
atomic_target = nil
atomic_client = nil
atomic_committed = false
pending_stages = []
selected_entries = if atomic_inject
                     ARGV.to_h do |name|
                       [name, DSL_MAP.fetch(name) { raise "unknown DSL: #{name}" }]
                     end
                   else
                     EtlHelpers.selected_dsl_entries(DSL_MAP, ARGV)
                   end
begin
  selected_entries.each do |name, cfg|
    csv_name, input = inject_source(name, cfg, stats)
    next unless input

    EtlHelpers.database_targets(
      cfg,
      env_host: MssqlHelpers.env_any('MSSQL_HOST', 'GSABSS_HOST'),
      env_database: MssqlHelpers.env_any('MSSQL_DATABASE', 'GSABSS_DATABASE')
    ).each do |target|
      raise 'missing host: (set cfg[:database_connections][:host] or MSSQL_HOST)' if target.host.empty?
      raise 'missing database: (set cfg[:database_connections][:database] or MSSQL_DATABASE)' if target.database.empty?

      mode = inject_mode(cfg, target.connection)
      inject = inject_cfg(cfg, target.connection)
      # TinyTDS cancels a command after 5 seconds. Publishing millions of rows
      # takes longer. Zero waits until that command finishes.
      client = clients[target.host] ||= MssqlHelpers.connect!(target.host, timeout: 0)

      client.execute("USE #{MssqlHelpers.quote_ident(target.database)}").do

      if atomic_inject
        current_target = [target.host, target.database]
        atomic_target ||= current_target
        raise 'atomic inject requires one SQL host and database' unless atomic_target == current_target

        unless atomic_client
          client.execute('SET TRANSACTION ISOLATION LEVEL SERIALIZABLE').do
          client.execute('BEGIN TRAN').do
          lock_started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          acquire_atomic_inject_lock!(client)
          lock_seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - lock_started
          puts format('[TIMING] Atomic inject lock wait: %.3fs', lock_seconds)
          atomic_client = client
        end
      end

      where_sql = delete_where(cfg, target.connection)
      validate_inject_mode!(mode, where_sql)

      insert_started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      inserted, duplicate_check_seconds = import_applied_file(
        client, target, input, cfg,
        { name: name, mode: mode, where_sql: where_sql, atomic: atomic_inject, pending_stages: pending_stages }
      )
      insert_seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - insert_started
      rows_per_second = insert_seconds.positive? ? inserted / insert_seconds : inserted
      puts inject_timing(name, duplicate_check_seconds, insert_seconds, rows_per_second)

      run_post_inject_script(name, target, mode, input, inserted, inject)
      puts "[OK] #{name}: #{csv_name} -> #{target.label} (#{mode}, #{inserted} rows)"
      stats.ok!
    rescue StandardError => e
      begin
        client.execute('IF @@TRANCOUNT > 0 ROLLBACK TRAN').do
      rescue StandardError
        # ignore rollback failure
      end
      DataRunner::BcpStage.release(pending_stages)
      puts "[FAIL] #{name}: #{MssqlHelpers.target_label(target&.host, target&.database, target&.schema,
                                                        target&.table)}: #{e}"
      stats.fail!
      raise if atomic_inject
    end
  end
  if atomic_client
    commit_started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    atomic_client.execute('COMMIT TRAN').do
    puts format('[TIMING] Atomic commit: %.3fs', Process.clock_gettime(Process::CLOCK_MONOTONIC) - commit_started)
    atomic_committed = true
  end
ensure
  if atomic_client && !atomic_committed
    begin
      atomic_client.execute('IF @@TRANCOUNT > 0 ROLLBACK TRAN').do
    rescue StandardError
      # ignore rollback failure
    end
  end
  DataRunner::BcpStage.release(pending_stages)
  clients.each_value(&:close)
end

# -------------------------------------------------------------------------- }}}
# {{{ Execution summary

puts "\n#{stats.summary}"
puts 'Inject completed.'
exit 1 if stats.fail.positive?

# -------------------------------------------------------------------------- }}}
