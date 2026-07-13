#!/usr/bin/env ruby
# frozen_string_literal: true

# drop_tables.rb
#
# Drops SQL Server tables using DSL_MAP targets.
# - Uses DSL_MAP entries where step :drop_table is enabled.
# - Executes direct SQL:
#     IF OBJECT_ID(N'[schema].[table]', N'U') IS NOT NULL DROP TABLE [schema].[table]

require_relative 'dsl_map'
require_relative '../helpers/etl_helpers'
require_relative '../db/mssql_helpers'
require_relative '../constants/workflow'

def drop_sql(schema, table)
  q = MssqlHelpers.sql_qualified(schema, table)
  "IF OBJECT_ID(N'#{q}', N'U') IS NOT NULL DROP TABLE #{q}"
end

puts 'Drop tables started.'

MssqlHelpers.load_dotenv!

stats = EtlHelpers::RunStats.new

clients = {}
begin
  EtlHelpers.selected_dsl_entries(DSL_MAP, ARGV).each do |name, cfg|
    unless Workflow.wants_step?(cfg, :drop_table)
      puts "[SKIP] #{name}: step disabled (:drop_table)"
      stats.skip!
      next
    end

    EtlHelpers.database_targets(
      cfg,
      env_host: MssqlHelpers.env_any('MSSQL_HOST', 'GSABSS_HOST'),
      env_database: MssqlHelpers.env_any('MSSQL_DATABASE', 'GSABSS_DATABASE')
    ).each do |target|
      raise 'missing host: (set cfg[:database_connections][:host] or MSSQL_HOST)' if target.host.empty?

      sql = drop_sql(target.schema, target.table)
      client = clients[target.host] ||= MssqlHelpers.connect!(target.host)

      client.execute("USE #{MssqlHelpers.quote_ident(target.database)}").do unless target.database.empty?
      client.execute(sql).do
      puts "[OK] #{name}: dropped #{target.label} if it existed"
      stats.ok!
    rescue StandardError => e
      puts "[FAIL] #{name}: #{MssqlHelpers.target_label(target&.host, target&.database, target&.schema,
                                                        target&.table)}: #{e}"
      stats.fail!
    end
  end
ensure
  clients.each_value(&:close)
end

puts "\n#{stats.summary}"
puts 'Drop tables completed.'
