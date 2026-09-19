# frozen_string_literal: true

module Dam
  class WatchFolderIngest
    # A folder people drop files into. Everything settled at the top level is
    # taken, and each original ends up in _ingested or _failed, so what is left
    # lying in the folder is exactly what has not been dealt with yet.
    class DropBox < WatchFolderIngest
      private

      def sweep
        settled(@folder.children).each do |path|
          # Checked per file, because the last one ingested may have filled it.
          # What is left waits in the folder for room rather than failing.
          break unless @location.accepts_uploads?

          claimed = claim(path)
          next unless claimed

          ingest_claimed(claimed, path.basename.to_s)
        end
      end

      def ingest_claimed(claimed, filename)
        asset = build_asset(claimed, filename)
        return report_failure(claimed, asset.errors.full_messages.to_sentence) unless asset.save

        finish(claimed, INGESTED)
        record_ingest(asset)
        @result.ingested += 1
      rescue StandardError => e
        # Also covers a failure after the file has been filed away, which would
        # otherwise be the one kind of trouble nothing recorded.
        report_failure(claimed.exist? ? claimed : @folder.join(INGESTED, filename), describe(e))
      ensure
        @io&.close
      end

      # Another sweep got there first when the rename finds nothing to move.
      def claim(path)
        destination = unique_path(@folder.join(PROCESSING), path.basename.to_s)
        File.rename(path, destination)
        destination
      rescue Errno::ENOENT
        nil
      end

      # Where a file goes once it has been dealt with, keeping its name unless
      # that name is taken.
      def finish(path, outcome)
        File.rename(path, unique_path(@folder.join(outcome), path.basename.to_s))
      end

      def report_failure(path, reason)
        @io&.close
        finish(path, FAILED) if path.exist?
        record_refusal(path, reason)
        @result.failed += 1
      end
    end
  end
end
