# frozen_string_literal: true

module Aim
  # Money a person types (#166). Rails casts text to a decimal only up to the
  # first character it does not expect, so "999,999,999.99" was saved as 999
  # and "$1,234.50" as 0, with no error. A money attribute named here reads
  # commas, a dollar sign, spaces and accounting parentheses ("(12.34)" is
  # -12.34); text that is not an amount, or too large for the column
  # (decimal(15,2)), is refused with a message and nothing is saved. Numbers
  # (the AI worker's, a form's already-cast value) pass through untouched.
  module MoneyAttributes
    extend ActiveSupport::Concern

    # decimal(15, 2): thirteen digits before the point.
    LIMIT = BigDecimal('10')**13
    AMOUNT = /\A-?(\d+(\.\d*)?|\.\d+)\z/
    # Commas, when there are any, group thousands: "1,234,567.89", not "1,2,3".
    GROUPED = /\A-?\d{1,3}(,\d{3})+(\.\d*)?\z/

    # A BigDecimal, nil for blank, or :invalid.
    def self.parse(value)
      return value unless value.is_a?(String)

      text = value.strip
      return if text.empty?

      negative = text.start_with?('(') && text.end_with?(')')
      text = text.delete_prefix('(').delete_suffix(')') if negative
      text = text.delete('$ ')
      return :invalid if text.include?(',') && !text.match?(GROUPED)

      text = text.delete(',')
      return :invalid unless text.match?(AMOUNT)

      amount = BigDecimal(text)
      amount = -amount if negative
      amount.abs >= LIMIT ? :invalid : amount
    end

    included do
      validate :money_readable
    end

    class_methods do
      def money_attributes(*names)
        names.each do |name|
          define_method(:"#{name}=") do |value|
            parsed = Aim::MoneyAttributes.parse(value)
            unreadable_money.delete(name)
            if parsed == :invalid
              unreadable_money[name] = value
            else
              super(parsed)
            end
          end
        end
      end
    end

    private

    def unreadable_money = (@unreadable_money ||= {})

    def money_readable
      unreadable_money.each do |name, value|
        errors.add(name, "\"#{value}\" is not an amount AIM can save")
      end
    end
  end
end
