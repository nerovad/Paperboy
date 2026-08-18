# frozen_string_literal: true

module Pfa
  module Work
    class RecordQuery
      def initialize(viewer:, filters: {}, registry: Registry.default)
        @viewer = viewer
        @filters = filters
        @registry = registry
      end

      def items
        providers.flat_map { |provider| safely { provider.records(viewer: @viewer, filters: @filters) } }
                 .uniq(&:key)
      end

      private

      def providers
        application = @filters[:application].presence
        application ? [@registry.fetch(application)] : @registry.to_a
      rescue KeyError
        []
      end

      def safely
        yield
      rescue StandardError => e
        Rails.logger.warn("PFA work provider failed: #{e.class}: #{e.message}")
        []
      end
    end
  end
end
