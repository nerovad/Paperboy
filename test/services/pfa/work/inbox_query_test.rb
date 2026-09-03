# frozen_string_literal: true

require 'test_helper'

module Pfa
  module Work
    class InboxQueryTest < ActiveSupport::TestCase
      Provider = Struct.new(:published) do
        def inbox_items(*) = published
        def records(*) = published
      end

      test 'aggregates providers and removes duplicate work keys' do
        item = work_item('forms:request:1')
        registry = Pfa::Work::Registry.new
        registry.register(:forms, Provider.new([item]))
        registry.register(:aim, Provider.new([item, work_item('aim:invoice:2')]))

        result = Pfa::Work::InboxQuery.new(viewer: {}, registry: registry).items

        assert_equal %w[forms:request:1 aim:invoice:2], result.map(&:key)
      end

      private

      def work_item(key)
        Pfa::Work::Item.new(
          key: key, application: :forms, source_type: 'Request',
          source_id: key, title: 'Request'
        )
      end
    end
  end
end
