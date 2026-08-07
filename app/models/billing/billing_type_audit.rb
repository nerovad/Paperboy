# frozen_string_literal: true

module Billing
  # Counts active-period TC60 rows for types enabled on the Billing Types page.
  class BillingTypeAudit
    Result = Data.define(:code, :name, :count)

    def initialize(period, types: nil, connection: BillingBase.connection)
      @period = period
      @types = types || BillingType.order(:TYPE).to_a
      @connection = connection
    end

    def results
      active_types = types.select(&:active?)
      return [] if active_types.empty?

      counts = connection.exec_query(query(active_types.map(&:code))).to_a.to_h do |row|
        [row.fetch('billing_type').to_s, row.fetch('row_count').to_i]
      end

      active_types.map do |type|
        Result.new(code: type.code, name: type.name, count: counts.fetch(type.code, 0))
      end
    end

    private

    attr_reader :connection, :period, :types

    def query(codes)
      sql = <<~SQL.squish
        SELECT T.[TYPE] AS billing_type, COUNT_BIG(*) AS row_count
        FROM GSABSS.dbo.tc60 T
        WHERE T.[DATE] >= ? AND T.[DATE] < DATEADD(day, 1, ?)
          AND T.[TYPE] IN (?)
        GROUP BY T.[TYPE]
      SQL
      ActiveRecord::Base.send(
        :sanitize_sql_array,
        [sql, period.start_date, period.end_date, codes]
      )
    end
  end
end
