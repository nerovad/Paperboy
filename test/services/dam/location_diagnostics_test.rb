# frozen_string_literal: true

require 'test_helper'

module Dam
  # A library whose previews all failed used to look exactly like one that was
  # still working. These are the counts that tell them apart.
  class LocationDiagnosticsTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    setup do
      ActiveStorage::Attachment.delete_all
      ActiveStorage::Blob.delete_all
      Dam::Job.delete_all
      Dam::Asset.delete_all
      Dam::IngestFailure.delete_all
      Dam::StorageLocation.delete_all
      @location = Dam::StorageLocation.create!(label: 'Share', kind: 'disk')
    end

    test 'counts the previews by state and names what is missing' do
      asset(derivative_state: 'ready')
      asset(derivative_state: 'ready')
      asset(derivative_state: 'pending')
      asset(derivative_state: 'failed', derivative_error: 'Errno::ENOENT ... convert')
      asset(derivative_state: 'none')

      assert_equal({ 'ready' => 2, 'pending' => 1, 'failed' => 1, 'none' => 1 },
                   diagnostics.preview_counts)
      assert_equal 1, diagnostics.previews_failed
      assert_equal 1, diagnostics.previews_waiting
      assert_equal 2, diagnostics.previews_missing
      assert_predicate diagnostics, :trouble?
    end

    test 'a library with nothing wrong reports no trouble' do
      asset(derivative_state: 'ready')

      assert_equal 0, diagnostics.previews_missing
      assert_not_predicate diagnostics, :trouble?
    end

    test 'rebuilding queues every asset without a preview and leaves the rest' do
      asset(derivative_state: 'ready')
      waiting = asset(derivative_state: 'pending')
      failed = asset(derivative_state: 'failed')

      queued = nil
      assert_enqueued_jobs 2, only: Dam::BuildDerivativesJob do
        queued = diagnostics.rebuild_previews!
      end

      assert_equal 2, queued
      assert_equal [waiting.id, failed.id].sort, enqueued_asset_ids.sort
    end

    test 'forgetting ingest failures lets the next scan try them again' do
      2.times { |index| failure("/share/file#{index}.jpg") }

      assert_equal 2, diagnostics.ingest_failure_count
      assert_equal 2, diagnostics.forget_ingest_failures!
      assert_equal 0, diagnostics.ingest_failure_count
      assert_not_predicate diagnostics, :trouble?
    end

    private

    def diagnostics = Dam::LocationDiagnostics.new(@location.reload)

    def asset(**attributes)
      Dam::Asset.create!({ title: 'An asset', media_type: 'image', storage_location: @location }
                           .merge(attributes))
    end

    def failure(path)
      Dam::IngestFailure.remember(location: @location, path: path,
                                  key: Digest::SHA256.hexdigest(path), reason: 'no')
    end

    def enqueued_asset_ids
      enqueued_jobs.select { |job| job['job_class'] == 'Dam::BuildDerivativesJob' }
                   .flat_map { |job| job['arguments'] }
    end
  end
end
