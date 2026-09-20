# frozen_string_literal: true

module Dam
  module ResourceSpace
    # Brings a ResourceSpace library into the DAM without moving a byte of it.
    #
    # Each resource becomes a referenced asset: the original stays where it is,
    # the title and metadata come from ResourceSpace's database rather than
    # from a filename, and the previews it has already generated are adopted
    # instead of rebuilt. An asset remembers the resource it came from, so a
    # second run updates what has changed rather than making everything twice.
    #
    # Where a resource's original cannot be found — ResourceSpace records many
    # of them as paths relative to its sync folder, which may not be mounted,
    # or may have been cleared — the resource is reported and skipped. A
    # catalogue entry pointing at nothing is worse than a missing one.
    class Import
      Result = Struct.new(:imported, :updated, :missing, :failed, :adopted, keyword_init: true) do
        def to_s
          "#{imported} imported, #{updated} updated, #{missing} without a file, #{failed} failed " \
            "(#{adopted} previews adopted)"
        end
      end

      UPLOADER_NAME = 'ResourceSpace import'
      PAGE = 500

      def initialize(location:, sync_base: nil, catalog: Catalog.new, limit: nil, dry_run: false)
        @location = location
        @sync_base = sync_base.presence && Pathname(sync_base)
        @catalog = catalog
        @limit = limit
        @dry_run = dry_run
        @result = Result.new(imported: 0, updated: 0, missing: 0, failed: 0, adopted: 0)
      end

      def call
        ensure_metadata_fields
        index = FilestoreIndex.new(filestore_root).build
        each_page do |resources|
          refs = resources.map { |row| row['ref'].to_i }
          metadata = @catalog.metadata_for(refs)
          resources.each { |row| import(row, index, metadata.fetch(row['ref'].to_i, {})) }
        end
        @result
      end

      # Resources whose original is nowhere this host can see, with the path
      # ResourceSpace believes it is at. The list an administrator needs before
      # deciding whether a share is missing or a sync folder was emptied.
      def unresolved(limit: 25)
        @unresolved ||= []
        @unresolved.first(limit)
      end

      private

      # Idempotent, and additive only: a field somebody has since renamed or
      # switched off is left exactly as they left it.
      def ensure_metadata_fields
        return if @dry_run

        existing = Dam::MetadataField.pluck(:key)
        Catalog::DAM_FIELDS.reject { |field| existing.include?(field[:key]) }
                           .each_with_index do |field, offset|
          Dam::MetadataField.create!(field.merge(position: Dam::MetadataField.maximum(:position).to_i + offset + 1))
        end
      end

      def filestore_root
        ENV.fetch('RS_FILESTORE', '/var/www/html/resourcespace/filestore')
      end

      def each_page
        after = 0
        taken = 0
        loop do
          page = @catalog.resources(after_ref: after, limit: PAGE)
          break if page.empty?

          page = page.first(@limit - taken) if @limit
          yield page
          taken += page.size
          after = page.last['ref'].to_i
          break if @limit && taken >= @limit
        end
      end

      def import(row, index, metadata)
        ref = row['ref'].to_i
        entry = index[ref]
        path = original_for(row, entry)

        return record_missing(row) if path.blank?

        asset = Dam::Asset.find_or_initialize_by(storage_location_id: @location.id, external_ref: ref.to_s)
        new_record = asset.new_record?
        return preview(asset, row, path) if @dry_run

        builder = AssetBuilder.new(asset, row: row, path: path, metadata: metadata, entry: entry)
        @result.adopted += 1 if builder.call == :adopted
        new_record ? @result.imported += 1 : @result.updated += 1
      rescue StandardError => e
        @result.failed += 1
        Rails.logger.warn("ResourceSpace import: resource #{row['ref']} failed — #{e.class}: #{e.message}")
      end

      # ResourceSpace keeps originals in two places: uploaded ones inside its
      # own filestore, and synced ones at a path relative to a folder it
      # watches. Both are tried before a resource is called missing.
      def original_for(row, entry)
        return entry.original if entry&.original&.file?

        relative = row['file_path'].to_s.strip
        return nil if relative.blank? || @sync_base.blank?

        candidate = @sync_base.join(relative)
        candidate.file? && candidate.size.positive? ? candidate : nil
      end

      def record_missing(row)
        @result.missing += 1
        @unresolved ||= []
        @unresolved << { ref: row['ref'], path: row['file_path'].presence || '(no path recorded)' }
      end

      def preview(asset, row, path)
        asset.new_record? ? @result.imported += 1 : @result.updated += 1
        Rails.logger.info("ResourceSpace import (dry run): #{row['ref']} → #{path}")
      end
    end
  end
end
