#!/usr/bin/env ruby
# frozen_string_literal: true

# Streams a strategy :replicate source into 05_DSL_Applied.
# Download, to_csv, and use_dsl are not part of this step.

require 'fileutils'
require_relative 'dsl_map'
require_relative '../helpers/etl_helpers'
require_relative '../helpers/replicate_extract'
require_relative '../db/mssql_helpers'
require_relative '../constants/workflow'
require_relative '../constants/workflow_paths'

APPLIED_DIR = WorkflowPaths::APPLIED_DIR
FileUtils.mkdir_p(APPLIED_DIR)

def replicate_target(cfg)
  EtlHelpers.source_database_target(
    cfg,
    env_host: MssqlHelpers.env_any('MSSQL_HOST', 'GSABSS_HOST'),
    env_database: MssqlHelpers.env_any('MSSQL_DATABASE', 'GSABSS_DATABASE')
  )
end

def replicate_client(clients, target)
  raise 'missing database target' if target.nil?
  raise 'missing host: (set source host or MSSQL_HOST)' if target.host.empty?
  raise 'missing database: (set source database or MSSQL_DATABASE)' if target.database.empty?

  clients[[target.host, target.database]] ||= MssqlHelpers.connect!(target.host, database: target.database)
end

def replicate_columns(client, cfg, target)
  columns = DataRunner::ReplicateExtract.source_columns(cfg)
  columns = DataRunner::ReplicateExtract.table_columns(client, target.schema, target.table) if columns.empty?
  raise "missing table or columns: #{target.label}" if columns.empty?

  columns
end

def write_applied_file(client, cfg, target, output_path, dsl)
  columns = replicate_columns(client, cfg, target)
  sql = DataRunner::ReplicateExtract.query_sql(target.schema, target.table, columns)
  partial = "#{output_path}.partial"
  File.open(partial, 'wb') do |io|
    DataRunner::ReplicateExtract.write_query(client, sql, io, cfg, columns: columns, dsl: dsl)
  end
  File.rename(partial, output_path)
rescue StandardError
  FileUtils.rm_f(partial) if partial
  raise
end

def replicate_entry(name, cfg, clients, stats)
  unless Workflow.wants_step?(cfg, :replicate)
    puts "[SKIP] #{name}: step disabled (:replicate)"
    stats.skip!
    return
  end
  unless EtlHelpers.source_strategy(cfg) == :replicate
    puts "[FAIL] #{name}: replicate step requires strategy :replicate"
    stats.fail!
    return
  end

  target = replicate_target(cfg)
  client = replicate_client(clients, target)
  output_path = File.join(APPLIED_DIR, EtlHelpers.output_for(cfg))
  write_applied_file(client, cfg, target, output_path, name)
  puts "[OK] #{name}: #{target.label} -> #{output_path}"
  stats.ok!
rescue StandardError => e
  puts "[FAIL] #{name}: #{e}"
  stats.fail!
end

puts 'Replicate started.'

MssqlHelpers.load_dotenv!
stats = EtlHelpers::RunStats.new
clients = {}

begin
  EtlHelpers.selected_dsl_entries(DSL_MAP, ARGV).each do |name, cfg|
    replicate_entry(name, cfg, clients, stats)
  end
ensure
  clients.each_value(&:close)
end

puts "\n#{stats.summary}"
puts 'Replicate completed.'
exit 1 if stats.fail.positive?
