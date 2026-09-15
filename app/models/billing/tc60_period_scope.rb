# frozen_string_literal: true

module Billing
  module Tc60PeriodScope
    PREDICATE = <<~SQL.squish.freeze
      ((T.[DATE] >= ? AND T.[DATE] < DATEADD(day, 1, ?))
       OR T.[POSTING_REF] = GSABSS.dbo.fnTC60PostingRef(T.[TYPE], ?))
    SQL

    def self.values(period)
      dates = [period.start_date, period.end_date].map { |value| Date.iso8601(value.to_s) }
      dates.map { |date| Arel.sql("'#{date.iso8601}'") }.then { |values| [*values, values.first] }
    end
  end
end
