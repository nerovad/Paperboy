# frozen_string_literal: true

module Dam
  # Sweeps every storage location's watch folder. Polled every minute by Solid
  # Queue; see Dam::WatchFolderIngest for what a sweep does with each file.
  class WatchFolderIngestJob < ApplicationJob
    queue_as :default

    def perform
      Dam::WatchFolderIngest.sweep_all.each do |result|
        next if result.ingested.zero? && result.failed.zero?

        Rails.logger.info("DAM folder ingest: #{result.ingested} ingested, " \
                          "#{result.failed} failed, #{result.skipped} already held")
      end
    end
  end
end
