#!/usr/bin/env ruby
# frozen_string_literal: true

# Dumps CREATE TABLE scripts from live SQL Server table metadata.

require 'fileutils'
require_relative 'dsl_map'
require_relative '../helpers/etl_helpers'
require_relative '../db/mssql_helpers'
require_relative '../constants/workflow'
require_relative '../constants/workflow_paths'

SQL_SCHEMA_DIR = WorkflowPaths::SQL_SCHEMA_DIR
FileUtils.mkdir_p(SQL_SCHEMA_DIR)

def sql_string(value)
  "N'#{value.to_s.gsub("'", "''")}'"
end

def sql_name(value)
  MssqlHelpers.quote_ident(value)
end

def query_rows(client, sql)
  client.execute(sql).to_a
end

def database_default_collation(client)
  rows = query_rows(
    client,
    <<~SQL
      SELECT CAST(DATABASEPROPERTYEX(DB_NAME(), 'Collation') AS sysname) AS collation_name
    SQL
  )

  rows.first&.fetch('collation_name').to_s
end

def table_object_id(client, schema, table)
  rows = query_rows(
    client,
    <<~SQL
      SELECT t.object_id
        FROM sys.tables AS t
        JOIN sys.schemas AS s
          ON s.schema_id = t.schema_id
       WHERE s.name = #{sql_string(schema)}
         AND t.name = #{sql_string(table)}
    SQL
  )

  rows.first&.fetch('object_id')
end

def columns_for(client, object_id)
  query_rows(
    client,
    <<~SQL
      SELECT
        c.column_id,
        c.name,
        typ.name AS type_name,
        type_schema.name AS type_schema,
        c.max_length,
        c.precision,
        c.scale,
        c.is_nullable,
        c.is_identity,
        ic.seed_value,
        ic.increment_value,
        c.is_computed,
        cc.definition AS computed_definition,
        dc.definition AS default_definition,
        c.collation_name
      FROM sys.columns AS c
      JOIN sys.types AS typ
        ON typ.user_type_id = c.user_type_id
      JOIN sys.schemas AS type_schema
        ON type_schema.schema_id = typ.schema_id
      LEFT JOIN sys.identity_columns AS ic
        ON ic.object_id = c.object_id
       AND ic.column_id = c.column_id
      LEFT JOIN sys.computed_columns AS cc
        ON cc.object_id = c.object_id
       AND cc.column_id = c.column_id
      LEFT JOIN sys.default_constraints AS dc
        ON dc.parent_object_id = c.object_id
       AND dc.parent_column_id = c.column_id
      WHERE c.object_id = #{object_id.to_i}
      ORDER BY c.column_id
    SQL
  )
end

def primary_key_for(client, object_id)
  rows = query_rows(
    client,
    <<~SQL
      SELECT
        kc.name AS constraint_name,
        i.type_desc,
        ic.key_ordinal,
        col.name AS column_name,
        ic.is_descending_key
      FROM sys.key_constraints AS kc
      JOIN sys.indexes AS i
        ON i.object_id = kc.parent_object_id
       AND i.index_id = kc.unique_index_id
      JOIN sys.index_columns AS ic
        ON ic.object_id = i.object_id
       AND ic.index_id = i.index_id
       AND ic.key_ordinal > 0
      JOIN sys.columns AS col
        ON col.object_id = ic.object_id
       AND col.column_id = ic.column_id
      WHERE kc.parent_object_id = #{object_id.to_i}
        AND kc.type = 'PK'
      ORDER BY ic.key_ordinal
    SQL
  )

  return nil if rows.empty?

  {
    name: rows.first.fetch('constraint_name'),
    clustered: rows.first.fetch('type_desc').to_s.include?('CLUSTERED'),
    columns: rows.map do |row|
      "#{sql_name(row.fetch('column_name'))} #{sql_true?(row.fetch('is_descending_key')) ? 'DESC' : 'ASC'}"
    end
  }
end

def sql_type(row)
  type_name = row.fetch('type_name')
  type_schema = row.fetch('type_schema')
  base = type_schema == 'sys' ? type_name : "#{sql_name(type_schema)}.#{sql_name(type_name)}"

  case type_name
  when 'varchar', 'char', 'varbinary', 'binary'
    length = row.fetch('max_length').to_i
    "#{base}(#{length == -1 ? 'max' : length})"
  when 'nvarchar', 'nchar'
    length = row.fetch('max_length').to_i
    "#{base}(#{length == -1 ? 'max' : length / 2})"
  when 'decimal', 'numeric'
    "#{base}(#{row.fetch('precision').to_i},#{row.fetch('scale').to_i})"
  when 'datetime2', 'datetimeoffset', 'time'
    "#{base}(#{row.fetch('scale').to_i})"
  else
    base
  end
end

def sql_true?(value)
  value == true || value.to_s == '1'
end

def identity_clause(row)
  return '' unless sql_true?(row.fetch('is_identity'))

  " IDENTITY(#{row.fetch('seed_value').to_i},#{row.fetch('increment_value').to_i})"
end

def nullability_clause(row)
  sql_true?(row.fetch('is_nullable')) ? 'NULL' : 'NOT NULL'
end

def explicit_collation?(row, default_collation)
  collation = row['collation_name'].to_s
  return false if collation.empty?

  collation.casecmp(default_collation.to_s).nonzero?
end

def column_line(row, default_collation)
  name = sql_name(row.fetch('name'))

  return "\t#{name} AS #{row.fetch('computed_definition')}" if sql_true?(row.fetch('is_computed'))

  line = "\t#{name} #{sql_type(row)}#{identity_clause(row)}"
  line = "#{line} COLLATE #{row.fetch('collation_name')}" if explicit_collation?(row, default_collation)
  line = "#{line} #{nullability_clause(row)}"
  line = "#{line} DEFAULT #{row.fetch('default_definition')}" unless row['default_definition'].to_s.empty?
  line
end

def write_live_sql(output_path, target, columns, primary_key, default_collation)
  lines = columns.map { |row| column_line(row, default_collation) }

  unless primary_key.nil?
    clustered = primary_key[:clustered] ? 'CLUSTERED' : 'NONCLUSTERED'
    lines << "\tCONSTRAINT #{sql_name(primary_key[:name])} PRIMARY KEY #{clustered} (#{primary_key[:columns].join(', ')})"
  end

  File.open(output_path, 'w') do |f|
    f.puts "-- HOST: #{target.host}" unless target.host.to_s.strip.empty?
    f.puts "USE #{sql_name(target.database)}"
    f.puts 'GO'
    f.puts
    f.puts "CREATE TABLE #{MssqlHelpers.sql_qualified(target.schema, target.table)}("
    lines.each_with_index do |line, idx|
      comma = idx == lines.length - 1 ? '' : ','
      f.puts "#{line}#{comma}"
    end
    f.puts ') ON [PRIMARY]'
    f.puts 'GO'
  end
end

puts 'Live SQL dump started.'

MssqlHelpers.load_dotenv!
stats = EtlHelpers::RunStats.new
clients = {}

begin
  EtlHelpers.selected_dsl_entries(DSL_MAP, ARGV).each do |name, cfg|
    unless Workflow.wants_step?(cfg, :to_sql)
      puts "[SKIP] #{name}: step disabled (:to_sql)"
      stats.skip!
      next
    end

    base = EtlHelpers.base_for(cfg)
    out = File.join(SQL_SCHEMA_DIR, "#{base}.sql")

    targets = EtlHelpers.database_targets(
      cfg,
      env_host: MssqlHelpers.env_any('MSSQL_HOST', 'GSABSS_HOST'),
      env_database: MssqlHelpers.env_any('MSSQL_DATABASE', 'GSABSS_DATABASE')
    )

    begin
      raise 'missing database:' if targets.any? { |target| target.database.empty? }

      targets.each_with_index do |target, idx|
        client_key = [target.host, target.database]
        client = clients[client_key] ||= MssqlHelpers.connect!(target.host, database: target.database)
        object_id = table_object_id(client, target.schema, target.table)
        raise "missing table #{target.label}" if object_id.nil?

        default_collation = database_default_collation(client)
        columns = columns_for(client, object_id)
        primary_key = primary_key_for(client, object_id)
        write_live_sql(out, target, columns, primary_key, default_collation) if idx.zero?
        next unless idx.positive?

        tmp = "#{out}.#{idx}.tmp"
        write_live_sql(tmp, target, columns, primary_key, default_collation)
        File.open(out, 'a') do |f|
          f.puts
          f.write(File.read(tmp))
        end
        FileUtils.rm_f(tmp)
      end

      puts "[OK] #{name} -> #{SQL_SCHEMA_DIR}/#{File.basename(out)} (#{targets.size} target(s))"
      stats.ok!
    rescue StandardError => e
      puts "[FAIL] #{name}: #{e}"
      stats.fail!
    end
  end
ensure
  clients.each_value(&:close)
end

puts "\n#{stats.summary}"
puts 'Live SQL dump completed.'
