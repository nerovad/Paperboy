# frozen_string_literal: true

require 'csv'
require 'set'
require_relative 'bcp_character_file'
require_relative 'etl_mapping_helpers'
require_relative 'sql_value'
require_relative '../db/mssql_helpers'

# Streams a source query into a bcp character file.
# TinyTDS caches every row unless each is given cache_rows: false.
module DataRunner
  module ReplicateExtract
    module_function

    def source_columns(cfg)
      EtlMappingHelpers.csv_mapping(cfg).filter_map { |entry| entry[:input] }.uniq
    end

    def query_sql(schema, table, columns)
      raise 'replicate source has no columns' if columns.empty?

      selected = columns.map { |column| MssqlHelpers.quote_ident(column) }.join(', ')
      "SELECT #{selected} FROM #{MssqlHelpers.sql_qualified(schema, table)}"
    end

    def table_columns(client, schema, table)
      rows = client.execute(table_column_sql(schema, table)).to_a
      rows.map { |row| row.fetch('name') }
    end

    def write_query(client, sql, io, cfg, columns:, dsl:)
      mapping = EtlMappingHelpers.csv_mapping(cfg)
      outputs = mapping.empty? ? columns : mapping.map { |entry| entry[:output] }
      BcpCharacterFile.write_row(io, outputs, dsl: dsl, columns: outputs)
      if dedup?(cfg)
        write_unique_rows(io, collect_rows(client, sql, mapping, columns, dsl), dsl: dsl, columns: outputs)
      else
        write_stream(client, sql, io, mapping, columns, outputs, dsl)
      end
    end

    def each_array(client, sql, &block)
      client.execute(sql).each({ cache_rows: false, as: :array }, &block)
    end

    def write_stream(client, sql, io, mapping, columns, outputs, dsl)
      row_number = 0
      each_array(client, sql) do |values|
        row_number += 1
        row = character_row(mapping, columns, values, row_number, dsl)
        BcpCharacterFile.write_row(io, row, dsl: dsl, columns: outputs)
      end
    end

    def collect_rows(client, sql, mapping, columns, dsl)
      rows = []
      each_array(client, sql) do |values|
        rows << character_row(mapping, columns, values, rows.length + 1, dsl)
      end
      rows
    end

    def character_row(mapping, columns, values, row_number, dsl)
      return values.map { |value| SqlValue.cell_text(value).to_s } if mapping.empty?

      row = {}
      columns.each_with_index { |column, index| row[column] = SqlValue.cell_text(values[index]) }
      mapping.map { |entry| canonical_field(entry, row, row_number, dsl) }
    end

    def canonical_field(entry, row, row_number, dsl)
      value = entry[:input].nil? ? nil : row[entry[:input]]
      mapped = EtlMappingHelpers.mapped_value_for(entry, value, row, row_number)
      SqlValue.canonical(mapped, entry[:data_type])
    rescue ArgumentError => e
      raise "#{dsl}: column #{entry[:output]}: #{e.message}"
    end

    def write_unique_rows(io, rows, dsl:, columns:)
      seen = Set.new
      rows.sort_by { |row| CSV.generate_line(row) }.each do |row|
        next unless seen.add?(CSV.generate_line(row))

        BcpCharacterFile.write_row(io, row, dsl: dsl, columns: columns)
      end
    end

    def dedup?(cfg)
      use_dsl = cfg[:use_dsl]
      use_dsl.is_a?(Hash) && use_dsl[:dedup] == true
    end

    def table_column_sql(schema, table)
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
    end

    def sql_string(value)
      "N'#{value.to_s.gsub("'", "''")}'"
    end
  end
end
