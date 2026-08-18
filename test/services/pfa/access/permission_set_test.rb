# frozen_string_literal: true

require 'test_helper'

module Pfa
  module Access
    class PermissionSetTest < ActiveSupport::TestCase
      test 'combines global and group permission keys' do
        global_scope = scope(%w[forms_global])
        group_scope = scope(%w[forms_group])

        OrgPermission.stub(:where, global_scope) do
          GroupPermission.stub(:where, group_scope) do
            keys = PermissionSet.new(org_chain: {}, group_ids: [12]).keys('form')

            assert_equal Set['forms_global', 'forms_group'], keys
          end
        end
      end

      test 'returns an empty set when permission storage is unavailable' do
        failure = ->(*) { raise ActiveRecord::ConnectionNotEstablished }

        OrgPermission.stub(:where, failure) do
          assert_empty PermissionSet.new(org_chain: {}, group_ids: []).keys('form')
        end
      end

      private

      def scope(keys)
        Object.new.tap do |relation|
          relation.define_singleton_method(:pluck) { |_column| keys }
        end
      end
    end
  end
end
