# frozen_string_literal: true

module Billing
  class FiscalPeriods
    QUERY = <<~SQL.squish.freeze
      DECLARE @fyear varchar(4) = GSABSS.dbo.fnGetFiscalYear(?);
      SELECT [Year] AS FYEAR, ApMon, sDate, eDate
      FROM GSABSS.dbo.GetFiscalData(@fyear, @fyear)
      ORDER BY sDate
    SQL

    def self.for(date = Date.current)
      sql = ActiveRecord::Base.send(:sanitize_sql_array, [QUERY, date.iso8601])
      BillingBase.connection.exec_query(sql).map { |period| period.transform_keys(&:downcase) }
    end
  end
end
