# frozen_string_literal: true

module Dam
  # Why a location's library does not look the way somebody expected.
  #
  # Two different failures land here. A file the scan would not take never
  # became an asset at all, and is remembered as a Dam::IngestFailure. A file
  # that ingested cleanly but whose preview could not be built is an asset
  # sitting at derivative_state 'failed' — and until this screen showed it, a
  # library of those looked exactly like one that was still working.
  class LocationDiagnostics
    SHOWN = 10

    def initialize(location)
      @location = location
    end

    # { 'ready' => 268, 'failed' => 4, ... }, in one query.
    def preview_counts = @location.assets.group(:derivative_state).count

    def previews_failed = preview_counts.fetch('failed', 0)

    def previews_waiting = preview_counts.fetch('pending', 0)

    def previews_missing = previews_failed + previews_waiting

    def preview_failures = @location.assets.where(derivative_state: 'failed').newest_first.limit(SHOWN)

    def ingest_failures = @location.ingest_failures.newest_first.limit(SHOWN)

    def ingest_failure_count = @location.ingest_failures.count

    def trouble? = previews_failed.positive? || ingest_failure_count.positive?

    # Forgets what would not ingest, so the next scan tries those files again
    # — after whatever was wrong with them has been put right.
    def forget_ingest_failures!
      forgotten = ingest_failure_count
      @location.ingest_failures.delete_all
      forgotten
    end

    # Queues a preview build for everything here that has none. What a host
    # needs after ImageMagick or ffmpeg finally arrives on it; nothing else
    # asks for those assets again.
    def rebuild_previews!
      queued = 0
      @location.assets.without_previews.find_each do |asset|
        Dam::BuildDerivativesJob.perform_later(asset.id)
        queued += 1
      end
      queued
    end
  end
end
