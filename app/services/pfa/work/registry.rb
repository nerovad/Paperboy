# frozen_string_literal: true

module Pfa
  module Work
    class Registry
      include Enumerable

      def self.default
        @default ||= new.tap do |registry|
          registry.register(:forms, Forms::WorkProvider.new)
          registry.register(:aim, Aim::WorkProvider.new)
        end
      end

      def initialize
        @providers = {}
      end

      def register(key, provider)
        raise ArgumentError, 'provider must implement inbox_items and records' unless provider_compatible?(provider)

        @providers[key.to_sym] = provider
      end

      def fetch(key) = @providers.fetch(key.to_sym)
      def each(&block) = @providers.each_value(&block)
      def keys = @providers.keys

      private

      def provider_compatible?(provider)
        provider.respond_to?(:inbox_items) && provider.respond_to?(:records)
      end
    end
  end
end
