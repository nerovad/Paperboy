#!/usr/bin/env ruby
# frozen_string_literal: true

# Exports configured SQL Server tables into 01_Download CSV files.

require 'csv'
require 'fileutils'
require_relative 'dsl_map'
require_relative '../helpers/etl_helpers'
require_relative '../db/mssql_helpers'
require_relative '../constants/workflow_paths'

DOWNLOAD_DIR = WorkflowPaths::DOWNLOAD_DIR
FileUtils.mkdir_p(DOWNLOAD_DIR)

def sql_string(value)
  "N'#{value.to_s.gsub("'", "''")}'"
end

def query_rows(client, sql)
  client.execute(sql).to_a
end

def table_columns(client, schema, table)
  rows = query_rows(
    client,
    <<~SQL
      SELECT c.name
        FROM sys.columns AS c
        JOIN sys.tables AS t
          ON t.object_id = c.object_id
        JOIN sys.schemas AS s
          ON s.schema_id = t.schema_id
       WHERE s.name = #{sql_string(schema)}
         AND t.name = #{sql_string(table)}
       ORDER BY c.column_id
    SQL
  )

  rows.map { |row| row.fetch('name') }
end

def export_sql(schema, table, columns)
  selected = columns.map { |column| MssqlHelpers.quote_ident(column) }.join(', ')
  "SELECT #{selected} FROM #{MssqlHelpers.sql_qualified(schema, table)}"
end

def output_path_for(cfg)
  local = EtlHelpers.source_local(cfg).to_s
  local = EtlHelpers.output_for(cfg) if local.strip.empty?
  File.join(DOWNLOAD_DIR, local)
end

def first_target_for(cfg)
  targets = EtlHelpers.database_targets(
    cfg,
    env_host: MssqlHelpers.env_any('MSSQL_HOST', 'GSABSS_HOST'),
    env_database: MssqlHelpers.env_any('MSSQL_DATABASE', 'GSABSS_DATABASE')
  )
  targets.first
end

puts 'From SQL started.'

MssqlHelpers.load_dotenv!
stats = EtlHelpers::RunStats.new
clients = {}

begin
  EtlHelpers.selected_dsl_entries(DSL_MAP, ARGV).each do |name, cfg|
    target = first_target_for(cfg)
    raise 'missing database target' if target.nil?
    raise 'missing host: (set cfg[:database_connections][:host] or MSSQL_HOST)' if target.host.empty?
    raise 'missing database: (set cfg[:database_connections][:database] or MSSQL_DATABASE)' if target.database.empty?

    client_key = [target.host, target.database]
    client = clients[client_key] ||= MssqlHelpers.connect!(target.host, database: target.database)
    columns = table_columns(client, target.schema, target.table)
    raise "missing table or columns: #{target.label}" if columns.empty?

    output_path = output_path_for(cfg)
    CSV.open(output_path, 'w') do |csv|
      csv << columns
      client.execute(export_sql(target.schema, target.table, columns)).each do |row|
        csv << columns.map { |column| row[column] }
      end
    end

    puts "[OK] #{name}: #{target.label} -> #{output_path}"
    stats.ok!
  rescue StandardError => e
    puts "[FAIL] #{name}: #{e}"
    stats.fail!
  end
ensure
  clients.each_value(&:close)
end

puts "\n#{stats.summary}"
puts 'From SQL completed.'
