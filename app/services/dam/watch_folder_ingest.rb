# frozen_string_literal: true

module Dam
  # Ingests what is sitting in a storage location's watch folder.
  #
  # Two modes, because a folder is either a drop box or somebody's library:
  #
  # 'move' claims each file by renaming it into _processing, so two sweeps that
  # overlap cannot both take it, and leaves it in _ingested or — with the
  # reason on its Jobs entry — _failed. Top level only: a drop box is flat.
  #
  # 'reference' reads a tree without disturbing it, and without copying it:
  # the asset records where the file is, and the library holds only the proxy
  # and thumbnail Dam::DerivativeBuilder makes of it. Nothing is renamed, so a
  # file is remembered by the digest of its path, and a unique index makes the
  # second sweep to reach one lose the race rather than double it. A share can
  # hold more files than a minute's sweep should touch, so each pass takes a
  # batch and leaves a cursor for the next one.
  class WatchFolderIngest
    PROCESSING = '_processing'
    INGESTED = '_ingested'
    FAILED = '_failed'
    OWN_FOLDERS = [PROCESSING, INGESTED, FAILED].freeze

    # A file still being copied in keeps changing; one untouched this long is
    # taken to be complete.
    SETTLE_TIME = 1.minute

    # Files read per leave-in-place sweep. Small enough that a minute is never
    # spent walking, large enough that a share drains in reasonable time.
    BATCH_SIZE = 100

    # Hidden files, Office lock files and the partial files browsers and copy
    # tools write before renaming to the real name.
    IGNORED = /\A(\.|~\$)|\.(tmp|part|partial|crdownload|download)\z/i

    UPLOADER_NAME = 'Watch folder'

    Result = Struct.new(:ingested, :failed, :skipped, keyword_init: true)

    # What Dam::Asset#apply_file_facts! reads off an upload. A file on a share
    # is not a form upload and does not have to pretend to be one.
    Upload = Data.define(:original_filename, :content_type, :size)

    def self.sweep_all(now: Time.current)
      Dam::StorageLocation.scanning.ordered.map { |location| for_location(location, now: now).call }
    end

    # The mode picks the sweep: a drop box empties, a library is only read.
    def self.for_location(location, now: Time.current)
      sweeper = location.moves_originals? ? DropBox : InPlace
      sweeper.new(location, now: now)
    end

    def initialize(location, now: Time.current)
      @location = location
      @folder = Pathname(location.watch_path)
      @now = now
    end

    def call
      @result = Result.new(ingested: 0, failed: 0, skipped: 0)
      return @result unless @folder.directory?

      sweep
      @result
    end

    private

    # A drop box takes what is at its top level; anything in a subfolder there
    # is somebody organising, not somebody filing.
    def settled(paths)
      paths.select { |path| path.file? && settled?(path) }
    end

    # An empty file is not a file that has finished arriving, and it is not an
    # asset either: a filestore of any age collects them, and ingesting one
    # gives a row nothing can ever draw.
    def settled?(path)
      return false if path.basename.to_s.match?(IGNORED)
      return false unless path.size.positive?

      path.mtime <= @now - SETTLE_TIME
    end

    def build_asset(path, filename)
      @io = File.open(path, 'rb')
      content_type = Marcel::MimeType.for(@io, name: filename)
      asset = Dam::Asset.new(storage_location: @location, uploaded_by_name: UPLOADER_NAME)
      asset.apply_file_facts!(Upload.new(filename, content_type, path.size))
      asset.file.attach(io: @io, filename: filename, content_type: content_type)
      asset
    end

    def describe(error) = "#{error.class}: #{error.message}"

    # Every ingest gets its viewable copies; the work itself waits for a
    # worker, so a scan is never held up by one large video.
    def queue_derivatives(asset)
      Dam::BuildDerivativesJob.perform_later(asset.id)
    end

    def record_ingest(asset)
      Dam::Job.record!(job_type: 'ingest', actor: nil, subject: asset,
                       log: "Ingested #{asset.filename} (#{asset.display_size}) into " \
                            "#{@location.label} from #{@location.watch_path}")
    end

    def record_refusal(path, reason)
      job = Dam::Job.enqueue!(job_type: 'ingest', subject: @location, total_items: 1)
      job.append_log("Could not ingest #{path.basename} from #{@location.watch_path}: #{reason}")
      job.update!(status: 'failed', error_message: reason, started_at: @now,
                  finished_at: Time.current, log: job.log)
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
