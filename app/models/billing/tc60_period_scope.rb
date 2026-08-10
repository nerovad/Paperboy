# frozen_string_literal: true

module Billing
  module Tc60PeriodScope
    PREDICATE = <<~SQL.squish.freeze
      ((T.[DATE] >= ? AND T.[DATE] < DATEADD(day, 1, ?))
       OR T.[POSTING_REF] = GSABSS.dbo.fnTC60PostingRef(T.[TYPE], ?))
    SQL

    def self.values(period)
      [period.start_date, period.end_date, period.start_date]
    end
  end
end
