# frozen_string_literal: true

# Copies AIM's legacy tables from gsa-sql22 [GSA_Scan] to GSASQL16 [GSA Scan]
# (2026-10-01). Reads gsa-sql22, never writes it: its tables stay as they are
# until AIM is confirmed working on GSASQL16.
#
#   bin/rails runner script/aim/copy_sql22_to_sql16.rb 'gsa-sql22\gsasql22'          # copy + verify
#   bin/rails runner script/aim/copy_sql22_to_sql16.rb 'gsa-sql22\gsasql22' --check  # verify only
#
# Safe to run again, e.g. after the cutover to catch rows the workers wrote to
# gsa-sql22 in between: missing rows are inserted (keeping their IDs), rows
# that differ are updated, and every row is then compared column by column.
# Both sides are reached as GSAETL (the GSABSS_* login), which reads
# gsa-sql22 and may create and write tables in [GSA Scan].
require 'tiny_tds'

module AimSql16Copy
  TABLES = {
    'Aim_Invoices' => { key: 'ID', identity: true },
    'Aim_Processing_Logs' => { key: 'ID', identity: true, computed: %w[InvoiceConcatID] },
    'Aim_Vendor_Aliases' => { key: 'ExtractedName', identity: false }
  }.freeze
  SCHEMA_FILE = Rails.root.join('db/aim/sql16_legacy_tables.sql')
  BATCH = 50

  module_function

  def run(source_server, check_only: false)
    source = client(dataserver: source_server, database: 'GSA_Scan')
    target = client(host: ENV.fetch('GSABSS_HOST'), database: 'GSA Scan')
    target.execute(File.read(SCHEMA_FILE)).do unless check_only
    ok = TABLES.map { |table, spec| copy_table(source, target, table, spec, check_only) }.all?
    puts ok ? 'ALL TABLES MATCH' : 'MISMATCH -- see above'
    exit(1) unless ok
  ensure
    [source, target].compact.each(&:close)
  end

  # A persisted computed column (Aim_Processing_Logs) needs the ANSI options
  # on for every write; TinyTDS sessions start with them off.
  SESSION = 'SET ANSI_NULLS ON; SET ANSI_PADDING ON; SET ANSI_WARNINGS ON; SET ARITHABORT ON; ' \
            'SET CONCAT_NULL_YIELDS_NULL ON; SET QUOTED_IDENTIFIER ON; SET NUMERIC_ROUNDABORT OFF;'

  def client(**target)
    TinyTds::Client.new(**target, username: ENV.fetch('GSABSS_USERNAME'), password: ENV.fetch('GSABSS_PASSWORD'),
                                  tds_version: '7.4', timeout: 120, login_timeout: 15)
                   .tap { _1.execute(SESSION).do }
  end

  def copy_table(source, target, table, spec, check_only)
    columns = writable_columns(source, table, spec)
    key = spec[:key]
    from = rows(source, table, key)
    unless check_only
      to = rows(target, table, key)
      missing = from.keys - to.keys
      changed = (from.keys & to.keys).reject { |k| same?(from[k], to[k], columns) }
      insert(target, table, columns, missing.map { from[_1] }, spec[:identity])
      changed.each { |k| update(target, table, columns, key, from[k]) }
      puts "#{table}: inserted #{missing.size}, updated #{changed.size}"
    end
    verify(table, key, from, rows(target, table, key), columns + spec.fetch(:computed, []))
  end

  def writable_columns(client, table, spec)
    client.execute("SELECT name FROM sys.columns WHERE object_id = OBJECT_ID('dbo.#{table}') ORDER BY column_id")
          .map { _1['name'] } - spec.fetch(:computed, [])
  end

  def rows(client, table, key)
    client.execute("SELECT * FROM dbo.#{table}").to_a.index_by { _1[key] }
  end

  def insert(target, table, columns, records, identity)
    return if records.empty?

    names = columns.map { "[#{_1}]" }.join(', ')
    records.each_slice(BATCH) do |slice|
      values = slice.map { |r| "(#{columns.map { literal(target, r[_1]) }.join(', ')})" }.join(",\n")
      sql = "INSERT INTO dbo.#{table} (#{names}) VALUES #{values};"
      sql = "SET IDENTITY_INSERT dbo.#{table} ON; #{sql} SET IDENTITY_INSERT dbo.#{table} OFF;" if identity
      target.execute(sql).do
    end
  end

  def update(target, table, columns, key, record)
    sets = (columns - [key]).map { "[#{_1}] = #{literal(target, record[_1])}" }.join(', ')
    target.execute("UPDATE dbo.#{table} SET #{sets} WHERE [#{key}] = #{literal(target, record[key])}").do
  end

  def literal(client, value)
    case value
    when nil then 'NULL'
    when Integer then value.to_s
    when Date then "'#{value.iso8601}'"
    when Time then "'#{value.strftime('%Y-%m-%dT%H:%M:%S.%L')}'"
    else "N'#{client.escape(value.to_s)}'"
    end
  end

  def same?(left, right, columns) = columns.all? { |c| comparable(left[c]) == comparable(right[c]) }

  def comparable(value) = value.is_a?(Time) ? value.strftime('%Y-%m-%dT%H:%M:%S.%L') : value

  def verify(table, key, from, to, columns)
    missing = from.keys - to.keys
    differ = (from.keys & to.keys).reject { |k| same?(from[k], to[k], columns) }
    extra = to.keys - from.keys
    puts "#{table}: source #{from.size}, GSASQL16 #{to.size}, missing #{missing.size}, " \
         "different #{differ.size}, only on GSASQL16 #{extra.size}"
    differ.first(3).each do |k|
      cols = columns.reject { |c| comparable(from[k][c]) == comparable(to[k][c]) }
      puts "  #{key}=#{k}: #{cols.join(', ')}"
    end
    missing.empty? && differ.empty?
  end
end

abort 'usage: bin/rails runner script/aim/copy_sql22_to_sql16.rb SOURCE_SERVER [--check]' if ARGV.first.blank?
AimSql16Copy.run(ARGV.first, check_only: ARGV.include?('--check'))
