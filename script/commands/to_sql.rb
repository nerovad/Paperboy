#!/usr/bin/env ruby
# frozen_string_literal: true

# {{{ Requirements and definitions.
#     Writes SQL Server CREATE TABLE scaffolds from DSL_MAP header mappings.
#
#     Output:
#       03_SQL_MAP/<base>.sql
#
#     Rules:
#     - Uses cfg[:database_connections] targets.
#     - Uses target :database (required)
#     - Uses target :schema   (optional, default: dbo)
#     - Uses target :table    (optional, default: derived from output/local base)
#     - Uses target :column_encryption_key for encrypted columns
#       (optional, default: CEK_<database>_<dataset>)
#     - Uses target :column_master_key for encrypted columns
#       (optional, default: CMK_<database>_<dataset>)
#     - Uses cfg[:header] output_column list (drops excluded; order preserved)
#     - Defaults: nvarchar(max), NOT NULL, no default value
#
#     Human can customize types/length/nullability/indexes after scaffold is
#     generated.

require 'fileutils'
require_relative 'dsl_map'
require_relative '../helpers/etl_helpers'
require_relative '../helpers/etl_mapping_helpers'
require_relative '../db/mssql_helpers'
require_relative '../constants/workflow'
require_relative '../constants/workflow_paths'

ROOT = File.expand_path('../..', __dir__)
$LOAD_PATH.unshift(ROOT)

SQL_MAP_DIR = WorkflowPaths::SQL_MAP_DIR
FileUtils.mkdir_p(SQL_MAP_DIR)

def sql_column_encryption_key(cfg, database, dataset_name, database_connection = nil)
  dbc = database_connection || cfg[:database_connection] || {}
  key = dbc[:column_encryption_key].to_s.strip
  return key unless key.empty?

  dataset = dataset_name.to_s.gsub(/[^A-Za-z0-9_]/, '')
  "CEK_#{database}_#{dataset}"
end

def sql_column_master_key(cfg, database, dataset_name, database_connection = nil)
  dbc = database_connection || cfg[:database_connection] || {}
  key = dbc[:column_master_key].to_s.strip
  return key unless key.empty?

  dataset = dataset_name.to_s.gsub(/[^A-Za-z0-9_]/, '')
  "CMK_#{database}_#{dataset}"
end

def sql_column_master_key_store_provider(cfg, database_connection = nil)
  dbc = database_connection || cfg[:database_connection] || {}
  provider = dbc[:column_master_key_store_provider].to_s.strip
  provider.empty? ? 'MSSQL_CERTIFICATE_STORE' : provider
end

def sql_column_master_key_path(cfg, database_connection = nil)
  dbc = database_connection || cfg[:database_connection] || {}
  path = dbc[:column_master_key_path].to_s.strip
  path.empty? ? 'CurrentUser/My/<CERTIFICATE_THUMBPRINT>' : path
end

def sql_column_encryption_key_value(cfg, database_connection = nil)
  dbc = database_connection || cfg[:database_connection] || {}
  value = dbc[:column_encryption_key_value].to_s.strip
  value.empty? ? '<ENCRYPTED_VALUE_FROM_SSMS_OR_POWERSHELL>' : value
end

def sql_column_definition(col)
  definition = "\t[#{col[:name]}] #{sql_data_type_definition(col[:data_type])} #{col[:nullability]}"
  default_value = sql_default_literal(col[:default_value], col[:data_type])
  return definition if default_value.nil?

  "#{definition} DEFAULT #{default_value}"
end

def primary_key_column(cols)
  cols.find { |col| EtlMappingHelpers.identity_column?(col) }
end

def sql_primary_key_constraint(table, col)
  "\tCONSTRAINT [PK_#{table}] PRIMARY KEY CLUSTERED ([#{col[:name]}] ASC)"
end

def sql_column_definition_lines(col, encryption_key)
  return [sql_column_definition(col)] unless encrypted_column?(col)

  nullability = encrypted_column_nullability(col[:nullability])
  [
    "\t[#{col[:name]}] #{sql_data_type_definition(col[:data_type])} ENCRYPTED WITH (",
    "\t\tCOLUMN_ENCRYPTION_KEY = [#{encryption_key}],",
    "\t\tENCRYPTION_TYPE = RANDOMIZED,",
    "\t\tALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256'",
    "\t) #{nullability}"
  ]
end

def encrypted_column?(col)
  col[:nullability].to_s.upcase.split.include?('ENCRYPTED')
end

def encrypted_columns?(cols)
  cols.any? { |col| encrypted_column?(col) }
end

def encrypted_column_nullability(nullability)
  cleaned = nullability.to_s.upcase.split.reject { |token| token == 'ENCRYPTED' }.join(' ')
  cleaned.empty? ? 'NULL' : cleaned
end

def sql_data_type_definition(data_type)
  raw = data_type.to_s.strip
  match = raw.match(/\A\[?([^\](\s]+)\]?\s*(\(.+\))?\z/)
  return raw unless match

  base_type = match[1]
  suffix = match[2]
  return base_type if suffix.nil? || suffix.empty?

  "#{base_type}#{suffix}"
end

def textimage_sql_type?(data_type)
  raw = data_type.to_s.strip.downcase
  match = raw.match(/\A\[?([^\](\s]+)\]?\s*(\((.+)\))?\z/)
  return false unless match

  base_type = match[1]
  suffix = match[3].to_s.strip

  %w[text ntext image].include?(base_type) ||
    (%w[varchar nvarchar varbinary].include?(base_type) && suffix == 'max')
end

def needs_textimage_on?(cols)
  cols.any? { |col| textimage_sql_type?(col[:data_type]) }
end

def sql_default_literal(default_value, data_type)
  return nil if default_value.nil?
  return nil if default_value.respond_to?(:call)

  stripped = default_value.is_a?(String) ? default_value.strip : default_value
  return nil if stripped.respond_to?(:empty?) && stripped.empty?

  type_name = data_type.to_s.strip.downcase
  return stripped.to_s if numeric_sql_type?(type_name) || boolean_sql_literal?(stripped) || sql_expression_literal?(stripped)

  "'#{stripped.to_s.gsub("'", "''")}'"
end

def numeric_sql_type?(type_name)
  %w[bigint decimal float int money numeric real smallint smallmoney tinyint].any? do |prefix|
    type_name.start_with?(prefix)
  end
end

def boolean_sql_literal?(value)
  value.to_s.match?(/\A(true|false)\z/i)
end

def sql_expression_literal?(value)
  token = value.to_s.strip
  return true if %w[CURRENT_TIMESTAMP NULL].include?(token.upcase)

  token.match?(/\A[A-Z_][A-Z0-9_]*\(.+\)\z/i)
end

# -------------------------------------------------------------------------- }}}
# {{{ Write SQL scaffold

def write_sql(output_path, host, database, schema, table, cols, encryption_options, append: false)
  encryption_key = encryption_options[:column_encryption_key]

  File.open(output_path, append ? 'a' : 'w') do |f|
    f.puts if append
    f.puts "-- HOST: #{host}" unless host.to_s.strip.empty?
    f.puts "USE [#{database}]"
    f.puts 'GO'
    f.puts
    f.puts 'IF EXISTS ('
    f.puts '  SELECT *'
    f.puts '    FROM sys.objects'
    f.puts "   WHERE object_id = OBJECT_ID(N'[#{schema}].[#{table}]')"
    f.puts "     AND type in (N'U')"
    f.puts ')'
    f.puts "DROP TABLE [#{schema}].[#{table}]"
    f.puts 'GO'
    f.puts
    encrypted_cols = encrypted_columns?(cols)
    write_column_encryption_drop_sql(f, encryption_options) if encrypted_cols
    f.puts 'SET ANSI_NULLS ON'
    f.puts 'GO'
    f.puts
    f.puts 'SET QUOTED_IDENTIFIER ON'
    f.puts 'GO'
    f.puts
    write_column_encryption_create_sql(f, encryption_options) if encrypted_cols
    f.puts "CREATE TABLE [#{schema}].[#{table}]("

    if cols.empty?
      # Still emit a valid table definition placeholder (human will adjust)
      f.puts "\t-- [col] [nvarchar] (max) NOT NULL"
    else
      primary_key = primary_key_column(cols)
      cols.each_with_index do |c, idx|
        comma = idx == cols.length - 1 && primary_key.nil? ? '' : ','
        lines = sql_column_definition_lines(c, encryption_key)
        lines[0...-1].each { |line| f.puts line }
        f.puts "#{lines[-1]}#{comma}"
      end

      f.puts sql_primary_key_constraint(table, primary_key) unless primary_key.nil?
    end

    table_options = needs_textimage_on?(cols) ? ' ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]' : ' ON [PRIMARY]'
    f.puts ")#{table_options}"
    f.puts 'GO'
  end
end

def write_column_encryption_drop_sql(f, encryption_options)
  cek = encryption_options[:column_encryption_key]
  cmk = encryption_options[:column_master_key]

  f.puts 'IF EXISTS ('
  f.puts '  SELECT *'
  f.puts '    FROM sys.column_encryption_keys'
  f.puts "   WHERE name = N'#{cek}'"
  f.puts ')'
  f.puts "DROP COLUMN ENCRYPTION KEY [#{cek}]"
  f.puts 'GO'
  f.puts
  f.puts 'IF EXISTS ('
  f.puts '  SELECT *'
  f.puts '    FROM sys.column_master_keys'
  f.puts "   WHERE name = N'#{cmk}'"
  f.puts ')'
  f.puts "DROP COLUMN MASTER KEY [#{cmk}]"
  f.puts 'GO'
  f.puts
end

def write_column_encryption_create_sql(f, encryption_options)
  cek = encryption_options[:column_encryption_key]
  cmk = encryption_options[:column_master_key]
  store_provider = encryption_options[:column_master_key_store_provider]
  key_path = encryption_options[:column_master_key_path]
  encrypted_value = encryption_options[:column_encryption_key_value]

  f.puts "CREATE COLUMN MASTER KEY [#{cmk}]"
  f.puts 'WITH ('
  f.puts "  KEY_STORE_PROVIDER_NAME = N'#{store_provider}',"
  f.puts "  KEY_PATH = N'#{key_path}'"
  f.puts ')'
  f.puts 'GO'
  f.puts
  f.puts "CREATE COLUMN ENCRYPTION KEY [#{cek}]"
  f.puts 'WITH VALUES ('
  f.puts "  COLUMN_MASTER_KEY = [#{cmk}],"
  f.puts "  ALGORITHM = 'RSA_OAEP',"
  f.puts "  ENCRYPTED_VALUE = #{encrypted_value}"
  f.puts ')'
  f.puts 'GO'
  f.puts
end

# -------------------------------------------------------------------------- }}}
# {{{ Main logic

puts 'DSL to SQL started.'

MssqlHelpers.load_dotenv!
stats = EtlHelpers::RunStats.new

EtlHelpers.selected_dsl_entries(DSL_MAP, ARGV).each do |name, cfg|
  unless Workflow.wants_step?(cfg, :to_sql)
    puts "[SKIP] #{name}: step disabled (:to_sql)"
    stats.skip!
    next
  end

  begin
    cols   = EtlMappingHelpers.output_columns(cfg)
    base   = EtlHelpers.base_for(cfg)
    out    = File.join(SQL_MAP_DIR, "#{base}.sql")

    database_targets = EtlHelpers.database_targets(
      cfg,
      env_host: MssqlHelpers.env_any('MSSQL_HOST', 'GSABSS_HOST'),
      env_database: MssqlHelpers.env_any('MSSQL_DATABASE', 'GSABSS_DATABASE')
    )

    database_targets.each_with_index do |target, idx|
      db = target.database
      raise 'missing database:' if db.empty?

      encryption_options = {
        column_encryption_key: sql_column_encryption_key(cfg, db, name, target.connection),
        column_master_key: sql_column_master_key(cfg, db, name, target.connection),
        column_master_key_store_provider: sql_column_master_key_store_provider(cfg, target.connection),
        column_master_key_path: sql_column_master_key_path(cfg, target.connection),
        column_encryption_key_value: sql_column_encryption_key_value(cfg, target.connection)
      }

      write_sql(out, target.host, db, target.schema, target.table, cols, encryption_options, append: idx.positive?)
    end

    puts "[OK] #{name} -> #{SQL_MAP_DIR}/#{File.basename(out)} (#{database_targets.size} target(s))"
    stats.ok!
  rescue StandardError => e
    puts "[FAIL] #{name}: #{e}"
    stats.fail!
  end
end

# -------------------------------------------------------------------------- }}},
# {{{ Execution summary

puts "\n#{stats.summary}"
puts 'DSL to SQL completed.'

# -------------------------------------------------------------------------- }}},
