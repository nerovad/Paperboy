# frozen_string_literal: true

module Dam
  class WatchFolderIngest
    # Somebody else's library, read where it stands. Nothing is moved, renamed
    # or copied: the asset records the path, and only the proxy and thumbnail
    # become bytes of the library's own.
    #
    # A file is remembered by the digest of its path, so a later scan passes
    # over it; one that could not be read is remembered too, or every pass
    # would try it again and log another failure for it.
    class InPlace < WatchFolderIngest
      # Paths whose keys are looked up in one query rather than one each.
      LOOKUP_CHUNK = 200

      private

      def sweep
        last = nil

        each_candidate(@location.scan_cursor) do |path|
          break unless @location.accepts_uploads?

          last = path.to_s
          ingest_in_place(path)
        end

        # A pass that reached nothing has walked the whole tree, so the cursor
        # is cleared and the next one starts at the top — where it finds only
        # what has been added since, everything else being already held.
        @location.update_column(:scan_cursor, last)
      end

      def ingest_in_place(path)
        asset = Dam::Asset.new(storage_location: @location, uploaded_by_name: UPLOADER_NAME)
        asset.apply_reference_facts!(path)

        return remember_failure(path, asset.source_key, refusals(asset)) unless asset.save

        record_ingest(asset)
        queue_derivatives(asset)
        @result.ingested += 1
      rescue ActiveRecord::RecordNotUnique
        # Another sweep reached it between the lookup and the save.
        @result.skipped += 1
      rescue StandardError => e
        remember_failure(path, Dam::Asset.source_key_for(path), describe(e))
      end

      def refusals(asset) = asset.errors.full_messages.to_sentence

      def remember_failure(path, key, reason)
        Dam::IngestFailure.remember(location: @location, path: path, key: key, reason: reason)
        record_refusal(path, reason)
        @result.failed += 1
      end

      # Walks the tree in sorted order and hands back a batch, skipping this
      # service's own folders, anything the location does not take, and
      # everything already ingested or already failed. The throw unwinds the
      # recursion, which a break inside the block would only do one level of.
      def each_candidate(cursor, &block)
        taken = 0
        catch(:batch_full) do
          each_chunk(cursor) do |path|
            block.call(path)
            taken += 1
            throw :batch_full if taken >= BATCH_SIZE
          end
        end
      end

      # Candidate paths are gathered a chunk at a time so the "have we got this
      # one already" question is one query per chunk instead of one per file.
      # At 94,000 files a scan cannot afford the other shape.
      def each_chunk(cursor, &block)
        chunk = []
        walk(@folder) do |path|
          next if cursor && path.to_s <= cursor
          next unless wanted?(path)

          chunk << path
          next if chunk.size < LOOKUP_CHUNK

          fresh(chunk).each(&block)
          chunk = []
        end
        fresh(chunk).each(&block)
      end

      def wanted?(path)
        settled?(path) &&
          @location.accepts_format?(path.extname) &&
          !@location.ignored_filename?(path.basename.to_s)
      end

      # The paths in this chunk that are neither held nor known to have failed.
      def fresh(chunk)
        return [] if chunk.empty?

        keys = chunk.to_h { |path| [path, Dam::Asset.source_key_for(path)] }
        known = Dam::Asset.where(storage_location_id: @location.id, source_key: keys.values)
                          .pluck(:source_key)
        known += Dam::IngestFailure.keys_for(@location, keys.values)

        chunk.reject { |path| known.include?(keys[path]) }
             .tap { |fresh| @result.skipped += chunk.size - fresh.size }
      end

      def walk(directory, &block)
        directory.children.sort.each do |child|
          if child.directory?
            walk(child, &block) unless OWN_FOLDERS.include?(child.basename.to_s)
          elsif child.file?
            block.call(child)
          end
        end
      end
    end
  end
end
