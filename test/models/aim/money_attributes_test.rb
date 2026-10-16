# frozen_string_literal: true

require 'test_helper'

module Aim
  # Typed money (#166): "999,999,999.99" was saved as 999 and "$1,234.50" as 0.
  class MoneyAttributesTest < ActiveSupport::TestCase
    test 'reads commas, dollar signs, spaces and accounting parentheses' do
      {
        '999,999,999.99' => '999999999.99', '$1,234.50' => '1234.50', '(12.34)' => '-12.34',
        '-5' => '-5', ' 570.72 ' => '570.72', '$ 1 234.00' => '1234', '.5' => '0.5', '9,999,999,999,999.99' => '9999999999999.99'
      }.each { |typed, amount| assert_equal BigDecimal(amount), MoneyAttributes.parse(typed), typed }
    end

    test 'blank is nil; numbers pass through; anything else is refused' do
      assert_nil MoneyAttributes.parse('  ')
      assert_equal 42.5, MoneyAttributes.parse(42.5)
      %w[abc 1,2,3 12,34 1.2.3 $ 10000000000000].each { |typed| assert_equal :invalid, MoneyAttributes.parse(typed), typed }
    end

    test 'every AIM money field reads typed amounts, and refuses one it cannot' do
      [[Invoice.new, :invoice_total], [Invoice.new, :subtotal], [Invoice.new, :sales_tax], [CodingLine.new, :amount],
       [FiscalRecord.new, :credit_amount], [BudgetUnitSetting.new, :second_approval_over]].each do |record, field|
        record.public_send(:"#{field}=", '$1,234,567.89')
        assert_equal BigDecimal('1234567.89'), record.public_send(field), "#{record.class} #{field}"

        record.public_send(:"#{field}=", 'twelve')
        record.valid?
        assert_includes record.errors[field], '"twelve" is not an amount AIM can save', "#{record.class} #{field}"

        record.public_send(:"#{field}=", '12')
        record.valid?
        assert_empty record.errors[field], 'a good amount clears the refusal'
      end
    end
  end
end
