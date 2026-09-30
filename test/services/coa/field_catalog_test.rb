# frozen_string_literal: true

require 'test_helper'

module Coa
  class FieldCatalogTest < ActiveSupport::TestCase
    test 'Billing and AIM read their lists from the one catalog' do
      assert_equal [Coa::Program, :program_id, true], BillingOptions::FIELD_CONFIG[:program]
      assert_equal [Coa::Object, :object_id, false], Aim::CoaCodes::LISTS['object_code']
      assert_equal [Coa::ObjectInference, :agency_object_code, true], Aim::CoaCodes::OPTION_LISTS['dept_object']
      assert_equal({ Coa::ObjectInference => :agency_object_name }, Aim::CoaCodes::NAMES)
    end

    test 'pairs are (code, name), in code order unless told otherwise, active only on request' do
      calls = []
      relation = Object.new
      relation.define_singleton_method(:where) { |c| (calls << [:where, c]) && self }
      relation.define_singleton_method(:order) { |c| (calls << [:order, c]) && self }
      relation.define_singleton_method(:pluck) { |*c| (calls << [:pluck, c]) && [%w[A1 Alpha]] }

      Coa::Program.stub(:where, ->(c) { (calls << [:scope, c]) && relation }) do
        assert_equal [%w[A1 Alpha]], FieldCatalog.pairs(:program, agency: 'GSA', active_only: true)
      end

      active = Coa::Program.column_names.include?('active')
      expected = [[:scope, { agency_id: 'GSA' }]] + (active ? [[:where, { active: true }]] : []) +
                 [%i[order program_id], [:pluck, %i[program_id short_name]]]
      assert_equal expected, calls
    end

    test 'an unknown field is refused' do
      assert_raises(KeyError) { FieldCatalog.fetch(:nope) }
      assert_raises(KeyError) { BillingOptions.new(agency_id: 'GSA').options_for(:fund) }
    end
  end
end
