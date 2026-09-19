# frozen_string_literal: true

module Dam
  class WatchFolderIngest
    # Somebody else's library, read without being disturbed. Nothing is moved
    # or renamed, so a file is remembered by the digest of its path, and a tree
    # too large for one sweep is worked through a batch at a time.
    class InPlace < WatchFolderIngest
      private

      def sweep
        last = nil

        each_candidate(@location.scan_cursor) do |path|
          break unless @location.accepts_uploads?

          last = path.to_s
          ingest_in_place(path)
        end

        # A pass that reached nothing has walked the whole tree, so the cursor is
        # cleared and the next one starts at the top — where it finds only what
        # has been added since, everything else being already ingested.
        @location.update_column(:scan_cursor, last)
      end

      def ingest_in_place(path)
        asset = build_asset(path, path.basename.to_s, source: path)
        unless asset.save
          record_refusal(path, asset.errors.full_messages.to_sentence)
          return @result.failed += 1
        end

        record_ingest(asset)
        @result.ingested += 1
      rescue ActiveRecord::RecordNotUnique
        # Another sweep ingested it between the check and the save.
        @result.skipped += 1
      rescue StandardError => e
        record_refusal(path, describe(e))
        @result.failed += 1
      ensure
        @io&.close
      end

      # Walks the tree in sorted order, skipping this service's own folders,
      # formats this location does not take and anything already read, and stops
      # once a batch is in hand. The throw unwinds the recursion, which a break
      # inside the block would only do one level of.
      def each_candidate(cursor)
        taken = 0
        catch(:batch_full) do
          walk(@folder) do |path|
            next if cursor && path.to_s <= cursor
            next unless settled?(path) && @location.accepts_format?(path.extname)

            if already_ingested?(path)
              @result.skipped += 1
              next
            end

            yield path
            taken += 1
            throw :batch_full if taken >= BATCH_SIZE
          end
        end
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

      def already_ingested?(path)
        Dam::Asset.where(storage_location_id: @location.id, source_key: source_key(path)).exists?
      end
    end
  end
end
