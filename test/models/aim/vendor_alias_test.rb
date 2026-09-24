# frozen_string_literal: true

require 'test_helper'

module Aim
  class VendorAliasTest < ActiveSupport::TestCase
    test 'reads its table from the aim schema' do
      assert_equal 'aim.vendor_aliases', Aim::VendorAlias.table_name
    end

    test 'learning a spelling records it and the official name maps to itself' do
      Aim::VendorAlias.learn!(extracted_name: '  AIRGAS USA LLC ', normalized_name: 'Airgas', learned_by: 'me@example.test')

      assert_equal 'Airgas', Aim::VendorAlias.find_by(extracted_name: 'AIRGAS USA LLC').normalized_name
      assert_equal 'Airgas', Aim::VendorAlias.find_by(extracted_name: 'Airgas').normalized_name
      assert_equal ['Airgas'], Aim::VendorAlias.official_names
    end

    test 'learning the same spelling again corrects it rather than duplicating it' do
      Aim::VendorAlias.learn!(extracted_name: 'AIRGAS USA LLC', normalized_name: 'Airgas', learned_by: 'a')
      Aim::VendorAlias.learn!(extracted_name: 'airgas usa llc', normalized_name: 'Airgas USA', learned_by: 'b')

      rows = Aim::VendorAlias.where('LOWER(extracted_name) = ?', 'airgas usa llc')
      assert_equal 1, rows.count
      assert_equal 'Airgas USA', rows.first.normalized_name
      assert_equal 'b', rows.first.learned_by
    end

    test 'a spelling is unique regardless of case' do
      Aim::VendorAlias.create!(extracted_name: 'ACME', normalized_name: 'Acme')

      assert_not Aim::VendorAlias.new(extracted_name: 'acme', normalized_name: 'Acme').valid?
    end

    test 'both names are required' do
      assert_raises(ArgumentError) { Aim::VendorAlias.learn!(extracted_name: '', normalized_name: 'Acme', learned_by: 'x') }
      assert_raises(ArgumentError) { Aim::VendorAlias.learn!(extracted_name: 'ACME', normalized_name: ' ', learned_by: 'x') }
    end
  end
end
