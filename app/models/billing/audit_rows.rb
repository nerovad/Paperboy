# frozen_string_literal: true

module Billing
  # Loads the source TC60 rows behind one distinct invalid audit value.
  class AuditRows
    def initialize(period, check, value, connection: BillingBase.connection)
      @period = period
      @check = check
      @value = value
      @connection = connection
    end

    def results
      connection.exec_query(query).to_a
    end

    private

    attr_reader :connection, :period, :check, :value

    def query
      sql = <<~SQL.squish
        SELECT T.*
        FROM GSABSS.dbo.tc60 T
        WHERE T.[DATE] >= ? AND T.[DATE] < DATEADD(day, 1, ?)
          AND LTRIM(RTRIM(T.#{check.column})) = ?
          AND NOT EXISTS (
            SELECT 1 FROM GSABSS.dbo.#{check.lookup_table} Z
            WHERE Z.#{check.lookup_column} = T.#{check.column}
          )
        ORDER BY T.[DATE]
      SQL
      ActiveRecord::Base.send(
        :sanitize_sql_array,
        [sql, period.start_date, period.end_date, value]
      )
    end
  end
end
