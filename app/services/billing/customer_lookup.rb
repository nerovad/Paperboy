# frozen_string_literal: true

module Billing
  class CustomerLookup
    COLUMNS = %w[agency division department unit service date quantity rate amount doc_nmbr
                 description other1 other2 other3].freeze

    def initialize(connection: BillingBase.connection)
      @connection = connection
    end

    def call(start_date:, end_date:, unit:)
      raise ArgumentError, 'Invalid date range' if start_date > end_date

      sql = <<~SQL.squish
        SELECT T.[SERVICE], T.[DATE], T.[DOC_NMBR], T.[DESCRIPTION], T.[OTHER1], T.[OTHER2],
               T.[OTHER3], T.[QUANTITY], T.[RATE], T.[COST]
        FROM #{tc60_table} T
        WHERE T.[DATE] >= ? AND T.[DATE] < DATEADD(day, 1, ?)
          AND T.[CUNIT] = ?
        ORDER BY T.[DATE], T.[SERVICE]
      SQL
      sanitized = ActiveRecord::Base.send(
        :sanitize_sql_array, [sql, start_date, end_date, unit.unit_id]
      )
      connection.exec_query(sanitized).map { |row| normalize(row, unit) }
    end

    private

    attr_reader :connection

    def tc60_table
      database = connection.pool.db_config.database.to_s
      raise ArgumentError, 'Invalid GSABSS database name' unless database.match?(/\A[A-Za-z0-9_]+\z/)

      "#{database}.dbo.TC60"
    end

    def normalize(row, unit)
      values = row.to_h.transform_keys { |key| key.to_s.downcase }
      fields = COLUMNS.to_h do |column|
        aliases = column == 'amount' ? %w[amount cost] : [column]
        [column.to_sym, aliases.lazy.map { |key| values[key] }.find { |value| !value.nil? }]
      end
      fields.merge(agency: unit.agency_id, division: unit.division_id,
                   department: unit.department_id, unit: unit.unit_id)
    end
  end
end
