# frozen_string_literal: true

module Paperboy
  # Keeps a CSV download from running formulas. A cell starting with one of
  # FORMULA_TRIGGERS is run as a formula by Excel and Sheets, and exported
  # values are typed in by people, so such a cell is prefixed with an
  # apostrophe rather than trusted (OWASP "CSV injection").
  #
  #   Paperboy::CsvSafe.defuse('=HYPERLINK("x")')  # => "'=HYPERLINK(\"x\")"
  #   Paperboy::CsvSafe.defuse_cell(-12.5)          # => -12.5 (only strings change)
  #   Paperboy::CsvSafe.restore("'=SUM(A1)")        # => "=SUM(A1)"
  #
  # Defuse text only. A numeric column meant for a spreadsheet or a macro --
  # money, where a credit is negative and starts with "-" -- must be left as
  # it is, so pass those cells through untouched.
  module CsvSafe
    FORMULA_TRIGGERS = /\A[=+\-@\t\r]/
    DEFUSED = /\A'(?=[=+\-@\t\r])/

    module_function

    def defuse(text)
      text.match?(FORMULA_TRIGGERS) ? "'#{text}" : text
    end

    # Defuses a String cell; anything else (nil, numbers, dates) is returned
    # unchanged.
    def defuse_cell(value)
      value.is_a?(String) ? defuse(value) : value
    end

    def defuse_row(values) = values.map { |value| defuse_cell(value) }

    # Undoes #defuse, for a file exported here and loaded back in.
    def restore(text)
      text.to_s.sub(DEFUSED, '')
    end
  end
end
