# frozen_string_literal: true

module Billing
  # Compares TC60 amounts and costs for the active Billing period.
  class CostAnalysis
    Check = Data.define(:key, :label, :predicate, :invalid_columns)
    Result = Data.define(:amount_cost_variance)

    AMOUNT_COST_PREDICATE = <<~SQL.squish.freeze
      COALESCE(T.[AMOUNT], 0) <> COALESCE(T.[COST], 0)
    SQL

    CHECKS = [
      Check.new(
        key: :amount_vs_cost,
        label: 'Amount vs Cost',
        predicate: AMOUNT_COST_PREDICATE,
        invalid_columns: %w[AMOUNT COST]
      )
    ].freeze

    def initialize(period, connection: BillingBase.connection)
      @period = period
      @connection = connection
    end

    def result
      row = connection.exec_query(query).first

      Result.new(
        amount_cost_variance: decimal(row.fetch('amount_cost_variance'))
      )
    end

    def self.find_check(key) = CHECKS.find { |check| check.key.to_s == key.to_s }

    def error_rows(key)
      check = self.class.find_check(key)
      raise KeyError, key unless check

      connection.exec_query(error_rows_query(check)).map do |row|
        AuditRow.new(row, invalid_columns: check.invalid_columns)
      end
    end

    private

    attr_reader :connection, :period

    def query
      sql = <<~SQL.squish
        SELECT
          COALESCE(SUM(COALESCE(T.[AMOUNT], 0) - COALESCE(T.[COST], 0)), 0)
            AS amount_cost_variance
        FROM GSABSS.dbo.tc60 T
        WHERE #{Tc60PeriodScope::PREDICATE}
      SQL
      ActiveRecord::Base.send(
        :sanitize_sql_array,
        [sql, *Tc60PeriodScope.values(period)]
      )
    end

    def error_rows_query(check)
      sql = <<~SQL.squish
        SELECT T.*
        FROM GSABSS.dbo.tc60 T
        WHERE #{Tc60PeriodScope::PREDICATE}
          AND #{check.predicate}
        ORDER BY T.[DATE]
      SQL
      ActiveRecord::Base.send(
        :sanitize_sql_array,
        [sql, *Tc60PeriodScope.values(period)]
      )
    end

    def decimal(value)
      BigDecimal(value.to_s)
    end
  end
end
