# frozen_string_literal: true

module Dam
  module ResourceSpace
    # Answers the three questions Dam::ResourceSpace::Import asks, from plain
    # hashes, so the import can be tested without a MySQL server holding a
    # copy of somebody's library.
    class FakeCatalog
      def initialize(resources: [], metadata: {})
        @resources = resources
        @metadata = metadata
      end

      def active_count = @resources.size

      def resources(after_ref: 0, limit: 500)
        @resources.select { |row| row['ref'].to_i > after_ref }.first(limit)
      end

      def metadata_for(refs) = @metadata.slice(*refs)
    end
  end
end
