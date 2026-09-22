# frozen_string_literal: true

module Dam
  module ResourceSpace
    # Brings an exported ResourceSpace library into the DAM, on the server the
    # DAM runs on — which never needs to reach ResourceSpace to do it.
    #
    # Reads a bundle written by Dam::ResourceSpace::Export. Each resource
    # becomes an asset: its original stored when it lived inside
    # ResourceSpace's own filestore, referenced where it stands when it is on
    # the graphics share, and reported and skipped when it is in neither — a
    # catalogue entry pointing at nothing is worse than a missing one. Every
    # field with a value comes across, and so do the collections.
    #
    # An asset remembers the resource it came from, so running this twice
    # updates rather than doubles.
    class Import
      Result = Struct.new(:imported, :updated, :stored, :referenced, :missing, :failed, :adopted,
                          :collections, keyword_init: true) do
        def to_s
          "#{imported} imported, #{updated} updated (#{stored} stored, #{referenced} referenced), " \
            "#{missing} without a file, #{failed} failed; #{adopted} previews adopted; " \
            "#{collections} collections"
        end
      end

      UPLOADER_NAME = 'ResourceSpace import'

      attr_reader :unresolved, :failures

      def initialize(location:, bundle:, sync_base: nil, limit: nil, dry_run: false)
        @location = location
        @bundle = bundle
        @sync_base = sync_base.presence && Pathname(sync_base)
        @limit = limit
        @dry_run = dry_run
        @result = Result.new(imported: 0, updated: 0, stored: 0, referenced: 0, missing: 0, failed: 0,
                             adopted: 0, collections: 0)
        @unresolved = []
        @failures = []
      end

      def call
        ensure_metadata_fields unless @dry_run
        records = @limit ? @bundle.resources.first(@limit) : @bundle.resources
        records.each { |record| import(record) }
        @result.collections = CollectionImport.new(location: @location, collections: @bundle.collections).call unless
          @dry_run
        @result
      end

      private

      # Additive only: a field somebody has since renamed or switched off is
      # left exactly as they left it.
      def ensure_metadata_fields
        existing = Dam::MetadataField.pluck(:key)
        position = Dam::MetadataField.maximum(:position).to_i
        @bundle.fields.reject { |field| existing.include?(field['key']) }.each do |field|
          position += 1
          Dam::MetadataField.create!(field.slice('key', 'label', 'field_type').merge('position' => position))
        end
      end

      def import(record)
        original, store = original_for(record)
        return record_missing(record) if original.nil?

        asset = Dam::Asset.find_or_initialize_by(storage_location_id: @location.id, external_ref: record['ref'].to_s)
        tally(asset, store)
        return if @dry_run

        previews = { proxy: @bundle.path(record['proxy']), thumbnail: @bundle.path(record['thumbnail']) }
        outcome = AssetBuilder.new(asset, record: record, original: original, store: store, previews: previews).call
        @result.adopted += 1 if outcome == :adopted
      rescue StandardError => e
        @result.failed += 1
        @failures << { ref: record['ref'], error: "#{e.class}: #{e.message}" }
      end

      # [path, store?] — the bundled copy of an original that lived in the
      # filestore, else the file on the graphics share, else nothing.
      def original_for(record)
        bundled = @bundle.path(record['original'])
        return [bundled, true] if bundled

        relative = record['file_path'].to_s.strip
        return nil if relative.blank? || @sync_base.blank?

        candidate = @sync_base.join(relative)
        candidate.file? && candidate.size.positive? ? [candidate, false] : nil
      end

      def tally(asset, store)
        asset.new_record? ? @result.imported += 1 : @result.updated += 1
        store ? @result.stored += 1 : @result.referenced += 1
      end

      def record_missing(record)
        @result.missing += 1
        @unresolved << { ref: record['ref'], path: record['file_path'].presence || '(no path recorded)' }
      end
    end
  end
end
