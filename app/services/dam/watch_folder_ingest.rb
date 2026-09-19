# frozen_string_literal: true

module Dam
  # Ingests whatever has been dropped into a storage location's watch folder.
  #
  # Each file is claimed by renaming it into _processing/ first, so two sweeps
  # that overlap never ingest the same file twice. It then ends up in
  # _ingested/ or, with the reason on its Jobs entry, in _failed/. Nothing is
  # deleted: the original stays beside the library's copy until someone clears
  # the folder out.
  class WatchFolderIngest
    PROCESSING = '_processing'
    INGESTED = '_ingested'
    FAILED = '_failed'

    # A file still being copied in keeps changing; one untouched this long is
    # taken to be complete.
    SETTLE_TIME = 1.minute

    # Hidden files, Office lock files and the partial files browsers and copy
    # tools write before renaming to the real name.
    IGNORED = /\A(\.|~\$)|\.(tmp|part|partial|crdownload|download)\z/i

    UPLOADER_NAME = 'Watch folder'

    # What Dam::Asset#apply_file_facts! reads off an upload. A dropped file is
    # not a form upload, and does not have to pretend to be one.
    Upload = Data.define(:original_filename, :content_type, :size)

    Result = Struct.new(:ingested, :failed, keyword_init: true)

    def self.sweep_all(now: Time.current)
      Dam::StorageLocation.watching.ordered.map { |location| new(location, now: now).call }
    end

    def initialize(location, now: Time.current)
      @location = location
      @folder = Pathname(location.watch_path)
      @now = now
    end

    def call
      result = Result.new(ingested: 0, failed: 0)
      return result unless @folder.directory?

      settled_files.each do |path|
        # Checked per file, because the last one ingested may have filled it.
        # What is left waits in the folder for room, rather than failing.
        break unless @location.accepts_uploads?

        outcome = ingest(path)
        result[outcome] += 1 if outcome
      end
      result
    end

    private

    def settled_files
      @folder.children.sort.select do |path|
        path.file? && !path.basename.to_s.match?(IGNORED) && path.mtime <= @now - SETTLE_TIME
      end
    end

    def ingest(path)
      claimed = claim(path)
      return nil unless claimed

      asset = build_asset(claimed, path.basename.to_s)
      return report_failure(claimed, asset.errors.full_messages.to_sentence) unless asset.save

      finish(claimed, INGESTED)
      record_ingest(asset)
      :ingested
    rescue StandardError => e
      # Also covers a failure after the file has been filed away, which would
      # otherwise be the one kind of trouble nothing recorded.
      report_failure(claimed || path, "#{e.class}: #{e.message}")
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

    def build_asset(claimed, filename)
      @io = File.open(claimed, 'rb')
      content_type = Marcel::MimeType.for(@io, name: filename)
      asset = Dam::Asset.new(storage_location: @location, uploaded_by_name: UPLOADER_NAME)
      asset.apply_file_facts!(Upload.new(filename, content_type, claimed.size))
      asset.file.attach(io: @io, filename: filename, content_type: content_type)
      asset
    end

    def report_failure(path, reason)
      @io&.close
      finish(path, FAILED) if path.exist?
      job = Dam::Job.enqueue!(job_type: 'ingest', subject: @location, total_items: 1)
      job.append_log("Could not ingest #{path.basename} from the watch folder: #{reason}")
      job.update!(status: 'failed', error_message: reason, started_at: @now,
                  finished_at: Time.current, log: job.log)
      :failed
    end

    def finish(claimed, outcome)
      File.rename(claimed, unique_path(@folder.join(outcome), claimed.basename.to_s))
    end

    def record_ingest(asset)
      Dam::Job.record!(job_type: 'ingest', actor: nil, subject: asset,
                       log: "Ingested #{asset.filename} (#{asset.display_size}) into " \
                            "#{@location.label} from its watch folder")
    end

    # Keeps the dropped name, stamping it only when that name is taken, so a
    # second drop of report.pdf does not overwrite the first one's original.
    def unique_path(directory, filename)
      FileUtils.mkdir_p(directory)
      candidate = directory.join(filename)
      return candidate unless candidate.exist?

      extension = File.extname(filename)
      directory.join("#{File.basename(filename, extension)}-#{Time.current.strftime('%Y%m%d%H%M%S%L')}#{extension}")
    end
  end
end
