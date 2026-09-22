# frozen_string_literal: true

module Dam
  module ResourceSpace
    # Rebuilds the collections people curated in ResourceSpace.
    #
    # Matched on ResourceSpace's own id rather than the name — there are two
    # called "Murals" — so a second run finds each one again and adds only the
    # members that are new. Order is kept, and so is nesting: parents are
    # linked once every collection exists, since a child can come before its
    # parent in the export.
    class CollectionImport
      PREFIX = 'resourcespace:'

      def initialize(location:, collections:)
        @location = location
        @collections = collections
      end

      # How many collections now exist for what ResourceSpace had.
      def call
        built = @collections.to_h { |source| [source['ref'], upsert(source)] }
        @collections.each do |source|
          link_parent(built, source)
          add_members(built[source['ref']], source['resources'])
        end
        built.size
      end

      private

      def upsert(source)
        collection = Dam::Collection.find_or_initialize_by(external_ref: "#{PREFIX}#{source['ref']}")
        collection.name = source['name'].presence || "ResourceSpace collection #{source['ref']}"
        collection.description = describe(source) if collection.new_record? || collection.description.blank?
        collection.created_by_name ||= Import::UPLOADER_NAME
        collection.save!
        collection
      end

      def describe(source)
        [source['description'].presence, 'Brought over from ResourceSpace.'].compact.join("\n\n")
      end

      def link_parent(built, source)
        parent = built[source['parent']]
        collection = built[source['ref']]
        collection.update!(parent: parent) if parent && collection.parent_id != parent.id
      end

      # The assets this location holds for those resources, in ResourceSpace's
      # order. A resource that did not come across — its original could not be
      # found — is simply not a member.
      def add_members(collection, refs)
        assets = @location.assets.where(external_ref: refs.map(&:to_s)).index_by(&:external_ref)
        present = collection.collection_assets.pluck(:asset_id)

        refs.each_with_index do |ref, index|
          asset = assets[ref.to_s]
          next if asset.nil? || present.include?(asset.id)

          collection.collection_assets.create!(asset: asset, position: index + 1)
        end
      end
    end
  end
end
