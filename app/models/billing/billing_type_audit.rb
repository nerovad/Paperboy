# frozen_string_literal: true

module Billing
  # Summarizes active-period TC60 rows for types enabled on the Billing Types page.
  class BillingTypeAudit
    Result = Data.define(:code, :name, :row_count, :error_count, :total_cost)

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
         [row.fetch('row_count').to_i, row.fetch('error_count').to_i,
          BigDecimal(row.fetch('total_cost').to_s)]]
      end

      active_types.map do |type|
        row_count, error_count, total_cost = counts.fetch(type.code, [0, 0, BigDecimal('0')])
        Result.new(code: type.code, name: type.name,
                   row_count: row_count, error_count: error_count, total_cost: total_cost)
      end
    end

    def error_rows(code)
      connection.exec_query(error_rows_query(code)).map { |row| build_audit_row(row) }
    end

    private

    attr_reader :connection, :period, :types

    def query(codes)
      sql = <<~SQL.squish
        SELECT Audited.billing_type,
               COUNT_BIG(*) AS row_count,
               SUM(Audited.is_error) AS error_count,
               COALESCE(SUM(Audited.cost), 0) AS total_cost
        FROM (
          SELECT T.[TYPE] AS billing_type,
                 T.[COST] AS cost,
                 CONVERT(bigint, CASE WHEN #{error_predicate} THEN 1 ELSE 0 END) AS is_error
          FROM GSABSS.dbo.tc60 T
          WHERE #{Tc60PeriodScope::PREDICATE}
            AND T.[TYPE] IN (?)
        ) Audited
        GROUP BY Audited.billing_type
      SQL
      ActiveRecord::Base.send(
        :sanitize_sql_array,
        [sql, *Tc60PeriodScope.values(period), codes]
      )
    end

    def error_rows_query(code)
      flags = Audit::GROUPS.flat_map(&:checks).map do |check|
        "CASE WHEN #{error_condition(check)} THEN 1 ELSE 0 END AS audit_error_#{check.key}"
      end
      sql = <<~SQL.squish
        SELECT T.*, #{flags.join(', ')}
        FROM GSABSS.dbo.tc60 T
        WHERE #{Tc60PeriodScope::PREDICATE}
          AND T.[TYPE] = ?
          AND (#{error_predicate})
        ORDER BY T.[CUNIT], T.[DATE]
      SQL
      ActiveRecord::Base.send(
        :sanitize_sql_array,
        [sql, *Tc60PeriodScope.values(period), code]
      )
    end

    def error_predicate
      Audit::GROUPS.flat_map(&:checks).map { |check| error_condition(check) }.join(' OR ')
    end

    def error_condition(check)
      <<~SQL.squish
        (NULLIF(LTRIM(RTRIM(T.#{check.column})), '') IS NOT NULL
         AND NOT EXISTS (
           SELECT 1 FROM GSABSS.dbo.#{check.lookup_table} Z
           WHERE Z.#{check.lookup_column} = T.#{check.column}
         ))
      SQL
    end

    def build_audit_row(row)
      checks = Audit::GROUPS.flat_map(&:checks)
      invalid_columns = checks.filter_map do |check|
        check.column if row.delete("audit_error_#{check.key}").to_i == 1
      end
      AuditRow.new(row, invalid_columns: invalid_columns)
    end
  end
end
