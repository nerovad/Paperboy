#!/usr/bin/env ruby
# frozen_string_literal: true

# create_tables.rb
#
# Executes SQL Server scripts in 03_SQL_MAP to create tables.
# - Uses DSL_MAP entries where step :create_table is enabled.
# - Resolves each SQL file as 03_SQL_MAP/<base>.sql.
# - Splits scripts on SQL Server "GO" batch separators.
# - Executes each batch via TinyTDS.

require_relative '../commands/dsl_map'
require_relative '../helpers/etl_helpers'
require_relative '../db/mssql_helpers'
require_relative '../constants/workflow'
require_relative '../constants/workflow_paths'

SQL_MAP_DIR = WorkflowPaths::SQL_MAP_DIR

def split_batches(sql_text)
  batches = []
  buf = []
  host = nil

  sql_text.each_line do |line|
    marker = line.strip
    host_marker = marker.match(/\A--\s*HOST:\s*(.+?)\s*\z/i)
    if host_marker && buf.join.strip.empty?
      host = host_marker[1].strip
      next
    end

    next_count = marker.match(/\AGO(?:\s+(\d+))?\z/i)

    if next_count
      batch = buf.join.strip
      repeat = (next_count[1] || '1').to_i
      repeat = 1 if repeat < 1

      repeat.times { batches << { host: host, sql: batch } } unless batch.empty?
      buf.clear
    else
      buf << line
    end
  end

  tail = buf.join.strip
  batches << { host: host, sql: tail } unless tail.empty?
  batches
end

puts 'Create tables started.'

MssqlHelpers.load_dotenv!

stats = EtlHelpers::RunStats.new

clients = {}
begin
  EtlHelpers.selected_dsl_entries(DSL_MAP, ARGV).each do |name, cfg|
    unless Workflow.wants_step?(cfg, :create_table)
      puts "[SKIP] #{name}: step disabled (:create_table)"
      stats.skip!
      next
    end

    base = EtlHelpers.base_for(cfg)
    path = File.join(SQL_MAP_DIR, "#{base}.sql")

    unless File.exist?(path)
      puts "[FAIL] #{name}: missing #{SQL_MAP_DIR}/#{File.basename(path)}"
      stats.fail!
      next
    end

    begin
      sql = File.read(path)
      batches = split_batches(sql)

      if batches.empty?
        puts "[SKIP] #{name}: #{File.basename(path)} has no executable SQL batches"
        stats.skip!
        next
      end

      batches.each do |batch|
        host = batch[:host]
        client = clients[host] ||= MssqlHelpers.connect!(host)
        client.execute(batch[:sql]).do
      end

      puts "[OK] #{name}: #{File.basename(path)} executed #{batches.size} batch(es)"
      stats.ok!
    rescue StandardError => e
      puts "[FAIL] #{name}: #{File.basename(path)}: #{e}"
      stats.fail!
    end
  end
ensure
  clients.each_value(&:close)
end

puts "\n#{stats.summary}"
puts 'Create tables completed.'
