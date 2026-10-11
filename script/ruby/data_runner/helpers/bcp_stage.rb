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

    def self.column_type(spec)
      return spec[:data_type] || spec['data_type'] if spec.is_a?(Hash)

      spec
    end

    def self.column_nullability(spec)
      return nil unless spec.is_a?(Hash)

      spec[:nullability] || spec['nullability']
    end

    def self.count_sql(schema, table)
      "SELECT COUNT_BIG(*) AS loaded FROM #{MssqlHelpers.sql_qualified(schema, table)}"
    end

    def self.select_expr(column, spec)
      data_type = column_type(spec)
      quoted = "stage.#{MssqlHelpers.quote_ident(column)}"
      if SqlValue.binary?(data_type)
        "CONVERT(#{sql_type(data_type)}, NULLIF(#{quoted}, N''), 2)"
      elsif SqlValue.blank_becomes_null?(data_type)
        "CONVERT(#{sql_type(data_type)}, NULLIF(#{quoted}, N''))"
      elsif SqlValue.not_null_text?(data_type, column_nullability(spec))
        "ISNULL(#{quoted}, N'')"
      else
        quoted
      end
    end

    def self.sql_type(data_type)
      type = data_type.to_s.strip
      return type if TYPE_PATTERN.match?(type)

      raise "unsupported SQL type #{data_type.inspect}"
    end

    # A child extract can contain keys created after its parent snapshot.
    # Those rows are not in the loaded parent, so the schema foreign key
    # would reject the whole insert.
    def self.missing_parent_count_sql(schema, stage, parent_table, column, parent_column, data_type)
      "SELECT COUNT_BIG(*) AS skipped FROM #{staged(schema, stage)} WHERE #{missing_parent_predicate(schema, parent_table, column, parent_column, data_type)}"
    end

    def self.missing_parent_delete_sql(schema, stage, parent_table, column, parent_column, data_type)
      "DELETE stage FROM #{staged(schema, stage)} WHERE #{missing_parent_predicate(schema, parent_table, column, parent_column, data_type)}"
    end

    def self.staged(schema, stage)
      "#{MssqlHelpers.sql_qualified(schema, stage)} AS stage"
    end

    def self.missing_parent_predicate(schema, parent_table, column, parent_column, data_type)
      parent_sql = MssqlHelpers.sql_qualified(schema, parent_table)
      converted = "TRY_CONVERT(#{sql_type(data_type)}, stage.#{MssqlHelpers.quote_ident(column)})"
      parent_key = "parent.#{MssqlHelpers.quote_ident(parent_column)}"
      "NOT EXISTS (SELECT 1 FROM #{parent_sql} AS parent WHERE #{parent_key} = #{converted})"
    end
  end
end
