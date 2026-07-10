#!/usr/bin/env ruby
# frozen_string_literal: true

# inject.rb

# {{{ Requirements and definitions.
#
# Loads 05_DSL_Applied/*.csv into SQL Server using TinyTDS.
#
# Modes:
# - :truncate_insert : TRUNCATE + INSERT all rows
# - :append          : INSERT all rows
# - :delete_insert   : DELETE (database_connections entry inject.delete_where) + INSERT all rows
#
# Connection is configured via ENV:
#   MSSQL_HOST      (required default host) e.g. "gsasql16" or "gsasql16.ent.co.ventura.gsa"
#   MSSQL_PORT      (optional)  default 1433
#   MSSQL_USERNAME  (required)
#   MSSQL_PASSWORD  (required)
#   MSSQL_TDSVER    (optional)  default "7.4"
#   MSSQL_ENCRYPT   (optional)  "true"/"false" (TinyTDS supports :encrypt on newer stacks)
#
# Notes:
# - This is row-by-row insert (simple + reliable). Bulk later.

require 'csv'
require 'bigdecimal'
require 'date'
require 'rbconfig'
require 'time'
require_relative 'dsl_map'
require_relative '../helpers/etl_helpers'
require_relative '../helpers/etl_mapping_helpers'
require_relative '../db/mssql_helpers'
require_relative '../constants/workflow'
require_relative '../constants/workflow_paths'

ROOT = File.expand_path('../..', __dir__)
$LOAD_PATH.unshift(ROOT)

APPLIED_DIR = WorkflowPaths::APPLIED_DIR

# -------------------------------------------------------------------------- }}}
# {{{ Helper: build_insert_sql

# Build INSERT statement with parameter placeholders. TinyTDS supports named
# parameters via :name => value in some patterns, but the most reliable
# cross-version approach is to safely literal-quote values. For v1, we do
# literal quoting via the connection's escape method.

def build_insert_sql(client, schema, table, columns, values, column_types = {})
  cols_sql = columns.map { |c| MssqlHelpers.quote_ident(c) }.join(', ')
  vals_sql = columns.zip(values).map do |column, value|
    sql_value_literal(client, value, column_types[column])
  end.join(', ')
  "INSERT INTO #{MssqlHelpers.sql_qualified(schema, table)} (#{cols_sql}) VALUES (#{vals_sql})"
end

def sql_value_literal(client, value, data_type = nil)
  return 'NULL' if value.nil?
  return 'NULL' if nullable_blank_sql_type?(data_type) && value.to_s.strip.empty?

  return numeric_sql_literal(value, data_type) if numeric_sql_type?(data_type)

  normalized = value_for_sql_type(value, data_type)
  "N'#{client.escape(normalized)}'"
end

def value_for_sql_type(value, data_type)
  type_name = sql_type_name(data_type)
  text = value.to_s.strip

  case type_name
  when 'date'
    parse_sql_date(text).strftime('%Y-%m-%d')
  when 'datetime', 'datetime2', 'smalldatetime', 'datetimeoffset'
    format_sql_time(parse_sql_datetime(text), '%Y-%m-%dT%H:%M:%S')
  when 'time'
    format_sql_time(parse_sql_time(text), '%H:%M:%S')
  else
    value.to_s
  end
end

def parse_sql_date(text)
  case text
  when %r{\A\d{1,2}/\d{1,2}/\d{4}\z}
    Date.strptime(text, '%m/%d/%Y')
  when %r{\A\d{1,2}/\d{1,2}/\d{2}\z}
    Date.strptime(text, '%m/%d/%y')
  when /\A\d{4}-\d{1,2}-\d{1,2}\z/
    Date.strptime(text, '%Y-%m-%d')
  else
    Date.parse(text)
  end
end

def parse_sql_datetime(text)
  case text
  when %r{\A\d{1,2}/\d{1,2}/\d{4} \d{1,2}:\d{2}(?::\d{2})? [AP]M\z}i
    Time.strptime(text, text.count(':') == 1 ? '%m/%d/%Y %I:%M %p' : '%m/%d/%Y %I:%M:%S %p')
  when %r{\A\d{1,2}/\d{1,2}/\d{2} \d{1,2}:\d{2}(?::\d{2})? [AP]M\z}i
    Time.strptime(text, text.count(':') == 1 ? '%m/%d/%y %I:%M %p' : '%m/%d/%y %I:%M:%S %p')
  else
    Time.parse(text)
  end
end

def parse_sql_time(text)
  case text
  when /\A\d{1,2}:\d{2}(?::\d{2})? [AP]M\z/i
    Time.strptime(text, text.count(':') == 1 ? '%I:%M %p' : '%I:%M:%S %p')
  else
    Time.parse(text)
  end
end

def temporal_sql_type?(data_type)
  %w[date datetime datetime2 smalldatetime datetimeoffset time].include?(sql_type_name(data_type))
end

def nullable_blank_sql_type?(data_type)
  numeric_sql_type?(data_type) || temporal_sql_type?(data_type)
end

def numeric_sql_type?(data_type)
  %w[
    bigint bit decimal float int money numeric real smallint smallmoney tinyint
  ].include?(sql_type_name(data_type))
end

def numeric_sql_literal(value, data_type)
  text = value.to_s.strip
  normalized = normalized_numeric_text(text)

  if integer_sql_type?(data_type)
    Integer(normalized, 10).to_s
  elsif bit_sql_type?(data_type)
    bit_sql_literal(normalized)
  else
    BigDecimal(normalized).to_s('F')
  end
rescue ArgumentError
  raise "invalid #{data_type} value #{text.inspect}"
end

def normalized_numeric_text(text)
  normalized = text.tr(',', '')
  negative = normalized.start_with?('(') && normalized.end_with?(')')
  normalized = normalized[1...-1] if negative
  negative ||= normalized.start_with?('-')
  normalized = normalized.delete_prefix('-')
  normalized = normalized.delete_prefix('$')
  normalized = "-#{normalized}" if negative
  normalized
end

def integer_sql_type?(data_type)
  %w[bigint int smallint tinyint].include?(sql_type_name(data_type))
end

def bit_sql_type?(data_type)
  sql_type_name(data_type) == 'bit'
end

def bit_sql_literal(value)
  case value.downcase
  when '1', 'true', 't', 'yes', 'y' then '1'
  when '0', 'false', 'f', 'no', 'n' then '0'
  else
    Integer(value, 10).then do |integer|
      raise ArgumentError, 'bit value must be 0 or 1' unless [ 0, 1 ].include?(integer)

      integer.to_s
    end
  end
end

def format_sql_time(time, base_format)
  formatted = time.strftime(base_format)
  fraction = time.nsec.zero? ? '' : ".#{time.nsec.to_s.rjust(9, '0')[0, 7].sub(/0+\z/, '')}"
  "#{formatted}#{fraction}"
end

def sql_type_name(data_type)
  data_type.to_s.strip.downcase[/\A\[?([^\](\s]+)/, 1]
end

def column_type_map(cfg)
  EtlMappingHelpers.output_columns(cfg).to_h { |column| [ column[:name], column[:data_type] ] }
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

  [ path.to_s.strip, Array(args).map(&:to_s) ]
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

# -------------------------------------------------------------------------- }}}
# {{{ Main logic

puts 'Inject started.'

MssqlHelpers.load_dotenv!

stats = EtlHelpers::RunStats.new

clients = {}
begin
  EtlHelpers.selected_dsl_entries(DSL_MAP, ARGV).each do |name, cfg|
    unless Workflow.wants_step?(cfg, :inject)
      puts "[SKIP] #{name}: step disabled (:inject)"
      stats.skip!
      next
    end

    csv_name = EtlHelpers.output_for(cfg)
    input    = File.join(APPLIED_DIR, csv_name)

    unless File.exist?(input)
      puts "[SKIP] #{name}: missing #{APPLIED_DIR}/#{csv_name}"
      stats.fail!
      next
    end

    EtlHelpers.database_targets(
      cfg,
      env_host: MssqlHelpers.env_any('MSSQL_HOST', 'GSABSS_HOST'),
      env_database: MssqlHelpers.env_any('MSSQL_DATABASE', 'GSABSS_DATABASE')
    ).each do |target|
      raise 'missing host: (set cfg[:database_connections][:host] or MSSQL_HOST)' if target.host.empty?
      raise 'missing database: (set cfg[:database_connections][:database] or MSSQL_DATABASE)' if target.database.empty?

      mode = inject_mode(cfg, target.connection)
      inject = inject_cfg(cfg, target.connection)
      client = clients[target.host] ||= MssqlHelpers.connect!(target.host)

      client.execute("USE #{MssqlHelpers.quote_ident(target.database)}").do

      where_sql = delete_where(cfg, target.connection)

      client.execute('BEGIN TRAN').do

      case mode
      when :truncate_insert
        client.execute(truncate_sql(target.schema, target.table)).do

      when :append
        # no-op

      when :delete_insert
        raise 'inject mode :delete_insert requires inject.delete_where' if where_sql.empty?

        client.execute(delete_sql(target.schema, target.table, where_sql)).do

      else
        raise "unknown inject mode: #{mode.inspect}"
      end

      inserted = 0
      columns = nil
      column_types = column_type_map(cfg)
      identity_insert_enabled = false

      CSV.foreach(input, headers: true, encoding: 'bom|utf-8').with_index(2) do |row, line_number|
        if columns.nil?
          columns = row.headers.map(&:to_s)
          if needs_identity_insert?(cfg, columns)
            client.execute(identity_insert_sql(target.schema, target.table, true)).do
            identity_insert_enabled = true
          end
        end

        values = columns.map { |c| row[c] }

        begin
          sql = build_insert_sql(client, target.schema, target.table, columns, values, column_types)
        rescue StandardError => e
          raise "#{input}: CSV row #{line_number}: #{e.message}"
        end
        client.execute(sql).do
        inserted += 1
      end

      client.execute(identity_insert_sql(target.schema, target.table, false)).do if identity_insert_enabled
      client.execute('COMMIT TRAN').do
      run_post_inject_script(name, target, mode, input, inserted, inject)
      puts "[OK] #{name}: #{csv_name} -> #{target.label} (#{mode}, #{inserted} rows)"
      stats.ok!
    rescue StandardError => e
      begin
        client.execute('IF @@TRANCOUNT > 0 ROLLBACK TRAN').do
      rescue StandardError
        # ignore rollback failure
      end
      begin
        client.execute(identity_insert_sql(target.schema, target.table, false)).do if identity_insert_enabled
      rescue StandardError
        # ignore cleanup failure
      end
      puts "[FAIL] #{name}: #{MssqlHelpers.target_label(target&.host, target&.database, target&.schema,
                                                        target&.table)}: #{e}"
      stats.fail!
    end
  end
ensure
  clients.each_value(&:close)
end

# -------------------------------------------------------------------------- }}}
# {{{ Execution summary

puts "\n#{stats.summary}"
puts 'Inject completed.'

# -------------------------------------------------------------------------- }}}
