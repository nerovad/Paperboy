# frozen_string_literal: true

module Billing
  # Counts active-period TC60 rows for types enabled on the Billing Types page.
  class BillingTypeAudit
    Result = Data.define(:code, :name, :row_count, :error_count)

    def initialize(period, types: nil, connection: BillingBase.connection)
      @period = period
      @types = types || BillingType.order(:TYPE).to_a
      @connection = connection
    end

    def results
      active_types = types.select(&:active?)
      return [] if active_types.empty?

      counts = connection.exec_query(query(active_types.map(&:code))).to_a.to_h do |row|
        [row.fetch('billing_type').to_s,
         [row.fetch('row_count').to_i, row.fetch('error_count').to_i]]
      end

      active_types.map do |type|
        row_count, error_count = counts.fetch(type.code, [0, 0])
        Result.new(code: type.code, name: type.name,
                   row_count: row_count, error_count: error_count)
      end
    end

    def error_rows(code)
      connection.exec_query(error_rows_query(code)).to_a
    end

    private

    attr_reader :connection, :period, :types

    def query(codes)
      sql = <<~SQL.squish
        SELECT Audited.billing_type,
               COUNT_BIG(*) AS row_count,
               SUM(Audited.is_error) AS error_count
        FROM (
          SELECT T.[TYPE] AS billing_type,
                 CONVERT(bigint, CASE WHEN #{error_predicate} THEN 1 ELSE 0 END) AS is_error
          FROM GSABSS.dbo.tc60 T
          WHERE T.[DATE] >= ? AND T.[DATE] < DATEADD(day, 1, ?)
            AND T.[TYPE] IN (?)
        ) Audited
        GROUP BY Audited.billing_type
      SQL
      ActiveRecord::Base.send(
        :sanitize_sql_array,
        [sql, period.start_date, period.end_date, codes]
      )
    end

    def error_rows_query(code)
      sql = <<~SQL.squish
        SELECT T.*
        FROM GSABSS.dbo.tc60 T
        WHERE T.[DATE] >= ? AND T.[DATE] < DATEADD(day, 1, ?)
          AND T.[TYPE] = ?
          AND (#{error_predicate})
        ORDER BY T.[DATE]
      SQL
      ActiveRecord::Base.send(
        :sanitize_sql_array,
        [sql, period.start_date, period.end_date, code]
      )
    end

    def error_predicate
      Audit::GROUPS.flat_map(&:checks).map do |check|
        <<~SQL.squish
          (NULLIF(LTRIM(RTRIM(T.#{check.column})), '') IS NOT NULL
           AND NOT EXISTS (
             SELECT 1 FROM GSABSS.dbo.#{check.lookup_table} Z
             WHERE Z.#{check.lookup_column} = T.#{check.column}
           ))
        SQL
      end.join(' OR ')
    end
  end
end
