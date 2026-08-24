# frozen_string_literal: true

require 'test_helper'

module Coa
  class BillingOptionsTest < ActiveSupport::TestCase
    test 'restricts objects through the selected agency mapping' do
      relation = option_relation([['Professional Services', 2100]])
      relation.define_singleton_method(:where) do |conditions|
        raise "unexpected scope: #{conditions.inspect}" unless conditions == { agency_objects: { agency_id: 'GSA' } }

        self
      end
      object_scope = lambda do |association|
        assert_equal :object_inferences, association
        relation
      end

      Coa::Object.stub(:joins, object_scope) do
        options = BillingOptions.new(agency_id: 'GSA', restrict_to_agency: true).options_for(:object)

        assert_equal [{ label: '2100 - Professional Services', value: 2100 }], options
      end
    end

    test 'returns no agency-specific options without an agency' do
      lookup = BillingOptions.new(restrict_to_agency: true)

      BillingOptions::FIELD_CONFIG.each_key do |field|
        assert_empty lookup.options_for(field)
      end
    end

    private

    def option_relation(rows)
      Object.new.tap do |relation|
        relation.define_singleton_method(:distinct) { self }
        relation.define_singleton_method(:order) { |_column| self }
        relation.define_singleton_method(:pluck) { |_label, _value| rows }
      end
    end
  end
end
