# frozen_string_literal: true

require 'test_helper'

module Aim
  # One reading of an encumbrance and one list of chart-of-accounts fields,
  # for coding rules, coding lines and Fiscal's lookup files.
  class CodingFieldsTest < ActiveSupport::TestCase
    test 'an encumbrance splits into its type and number' do
      assert_equal %w[BDO 4640], Aim::CodingFields.split_encumbrance(' bdo_4640 ')
      assert_equal %w[CT 4620FY23], Aim::CodingFields.split_encumbrance('CT4620FY23')
      assert_equal ['DO', nil], Aim::CodingFields.split_encumbrance('DO_')
      assert_equal [nil, nil], Aim::CodingFields.split_encumbrance('12345')
    end

    test 'rules and lines read and write the encumbrance the same way' do
      [Aim::CodingRule.new, Aim::CodingLine.new].each do |row|
        row.encumbrance = 'bdo_4640x'

        assert_equal %w[BDO 4640x BDO_4640x], [row.encumbrance_type, row.encumbrance_number, row.encumbrance]
      end
    end

    test 'a line has the rules\' coding fields and an org number after the department' do
      assert_equal Aim::CodingFields::COA_FIELDS, Aim::CodingRule::CODING_FIELDS
      assert_equal %w[fund department org_number object_code], Aim::CodingLine::CODING_FIELDS.first(4)
      assert_equal Aim::CodingRule::CODING_FIELDS, Aim::CodingLine::CODING_FIELDS - %w[org_number]
    end

    test 'history rows are append only' do
      assert_includes Aim::InvoiceEvent, Aim::AppendOnly
      assert_includes Aim::CodingRuleChange, Aim::AppendOnly
    end
  end
end
