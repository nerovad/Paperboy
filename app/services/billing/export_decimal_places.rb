# frozen_string_literal: true

module Billing
  # Decimal places for GSABSS.dbo.Export_TC60_To_Billing_File.
  #
  # Export_TC60_Billing_Report_Names always passes @digits = 2. The export
  # rounds AMOUNT and COST to @digits, QUANTITY to @digits + 1, and RATE
  # to @digits + 2.
  module ExportDecimalPlaces
    DIGITS = 2
    BY_COLUMN = {
      'AMOUNT' => DIGITS,
      'QUANTITY' => DIGITS + 1,
      'RATE' => DIGITS + 2,
      'COST' => DIGITS
    }.freeze

    module_function

    def for(column)
      BY_COLUMN[column.to_s.upcase]
    end
  end
end
