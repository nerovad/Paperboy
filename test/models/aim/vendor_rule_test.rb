# frozen_string_literal: true

require 'test_helper'

module Aim
  class VendorRuleTest < ActiveSupport::TestCase
    test 'reads its table from the aim schema' do
      assert_equal 'aim.vendor_rules', Aim::VendorRule.table_name
    end

    test 'rules are one per line and found by vendor regardless of case' do
      Aim::VendorRule.create!(vendor_name: ' Airgas ', rules: "Invoice number is top right\n\nTake the amount due\n")

      rule = Aim::VendorRule.for_vendor('airgas')
      assert_equal ['Invoice number is top right', 'Take the amount due'], rule.rule_lines
    end

    test 'a vendor has one set of rules' do
      Aim::VendorRule.create!(vendor_name: 'Airgas', rules: 'x')

      assert_not Aim::VendorRule.new(vendor_name: 'AIRGAS', rules: 'y').valid?
    end

    test 'a vendor and rules are required' do
      assert_not Aim::VendorRule.new(vendor_name: '', rules: 'x').valid?
      assert_not Aim::VendorRule.new(vendor_name: 'Airgas', rules: '  ').valid?
    end
  end
end
