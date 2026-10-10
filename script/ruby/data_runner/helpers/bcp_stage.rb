# frozen_string_literal: true

require 'securerandom'
require_relative '../db/mssql_helpers'
require_relative 'sql_value'

# Staging columns follow the applied file, so bcp -c uses that order.
# The live insert names columns and still lands them when the table order differs.
module DataRunner
  class BcpStage
    TYPE_PATTERN = /\A[A-Za-z][A-Za-z0-9]*(\((max|\d+)(,\s*\d+)?\))?\z/

    def self.name_for(table)
      suffix = "_bcp_#{SecureRandom.hex(4)}"
      "#{table.to_s.byteslice(0, 128 - suffix.bytesize)}#{suffix}"
    end

    def self.create!(client, schema, table, columns)
      definitions = columns.map { |name| "#{MssqlHelpers.quote_ident(name)} nvarchar(max) NULL" }
      client.execute("CREATE TABLE #{MssqlHelpers.sql_qualified(schema, table)} (#{definitions.join(', ')})").do
    end

    def self.drop!(client, schema, table)
      client.execute("DROP TABLE IF EXISTS #{MssqlHelpers.sql_qualified(schema, table)}").do
    end

    def self.drop_record(record)
      client = MssqlHelpers.connect!(record.fetch(:host))
      begin
        client.execute("USE #{MssqlHelpers.quote_ident(record.fetch(:database))}").do
        drop!(client, record.fetch(:schema), record.fetch(:table))
      ensure
        client.close
      end
    end

    def self.release(pending)
      until pending.empty?
        record = pending.shift
        begin
          drop_record(record)
        rescue StandardError => e
          warn "[WARN] bcp stage drop failed #{record[:table]}: #{e}"
        end
      end
    end

    def self.insert_sql(schema, live, stage, columns, column_types)
      destination = columns.map { |column| MssqlHelpers.quote_ident(column) }.join(', ')
      selected = columns.map { |column| select_expr(column, column_types[column]) }.join(', ')
      live_sql = MssqlHelpers.sql_qualified(schema, live)
      stage_sql = MssqlHelpers.sql_qualified(schema, stage)
      "INSERT INTO #{live_sql} (#{destination}) SELECT #{selected} FROM #{stage_sql} AS stage"
    end

    def self.count_sql(schema, table)
      "SELECT COUNT_BIG(*) AS loaded FROM #{MssqlHelpers.sql_qualified(schema, table)}"
    end

    def self.select_expr(column, data_type)
      quoted = "stage.#{MssqlHelpers.quote_ident(column)}"
      return quoted unless SqlValue.blank_becomes_null?(data_type)

      "CONVERT(#{sql_type(data_type)}, NULLIF(#{quoted}, N''))"
    end

    def self.sql_type(data_type)
      type = data_type.to_s.strip
      return type if TYPE_PATTERN.match?(type)

      raise "unsupported SQL type #{data_type.inspect}"
    end
  end
end
