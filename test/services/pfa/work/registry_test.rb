# frozen_string_literal: true

require 'test_helper'

module Pfa
  module Work
    class RegistryTest < ActiveSupport::TestCase
      FakeProvider = Struct.new(:items) do
        def inbox_items(*) = items
        def records(*) = items
      end

      test 'registers and enumerates application providers' do
        registry = Pfa::Work::Registry.new
        provider = FakeProvider.new([])

        registry.register(:aim, provider)

        assert_equal [:aim], registry.keys
        assert_same provider, registry.fetch('aim')
        assert_equal [provider], registry.to_a
      end

      test 'rejects objects that do not implement the provider contract' do
        assert_raises(ArgumentError) { Pfa::Work::Registry.new.register(:bad, Object.new) }
      end
    end
  end
end
