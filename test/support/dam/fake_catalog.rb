# frozen_string_literal: true

module Dam
  module ResourceSpace
    # Answers what Dam::ResourceSpace::Export asks of a catalogue, from plain
    # hashes, so an export can be tested without a MySQL server holding a copy
    # of somebody's library.
    class FakeCatalog
      attr_reader :collections

      def initialize(resources: [], metadata: {}, fields: [], collections: [])
        @resources = resources
        @metadata = metadata
        @fields = fields
        @collections = collections
      end

      def active_count = @resources.size

      def resources(after_ref: 0, limit: 500)
        @resources.select { |row| row['ref'].to_i > after_ref }.first(limit)
      end

      def metadata_for(refs) = @metadata.slice(*refs)

      def fields_in_use = @fields
    end
  end
end
