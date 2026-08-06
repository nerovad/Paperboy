# frozen_string_literal: true

module Billing
  class MonthlyReportRunner
    PROCEDURE = 'GSABSS.dbo.MonthlyBilling'

    def initialize(report)
      @report = report
    end

    def call
      sql = <<~SQL.squish
        EXEC #{PROCEDURE} @sDate = ?, @eDate = ?
      SQL
      BillingBase.connection.exec_query(sanitize(sql, report.start_date, report.end_date))
    end

    private

    attr_reader :report

    def sanitize(sql, *values)
      ActiveRecord::Base.send(:sanitize_sql_array, [sql, *values])
    end
  end
end
