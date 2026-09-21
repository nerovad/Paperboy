# frozen_string_literal: true

require 'test_helper'

module Dam
  class WatchFolderIngestTest < ActiveSupport::TestCase
    setup do
      # This suite does not roll back between tests, so the DAM tables are
      # cleared the way the other model tests clear theirs.
      ActiveStorage::Attachment.delete_all
      ActiveStorage::Blob.delete_all
      Dam::Job.delete_all
      Dam::Asset.delete_all
      Dam::StorageLocation.delete_all
      @allowed = Pathname(Dir.mktmpdir('dam-roots'))
      @previous_roots = ENV.fetch('PAPERBOY_DAM_ROOTS', nil)
      ENV['PAPERBOY_DAM_ROOTS'] = @allowed.realpath.to_s
      @location = Dam::StorageLocation.create!(label: 'Photos', kind: 'disk',
                                               root: @allowed.join('photos').to_s,
                                               watch_path: @allowed.join('drop').to_s,
                                               ingest_mode: 'move')
      @drop = Pathname(@location.watch_path)
    end

    teardown do
      ENV['PAPERBOY_DAM_ROOTS'] = @previous_roots
      FileUtils.rm_rf(@allowed)
    end

    test 'ingests a settled file into the location and moves the original aside' do
      drop('minutes.txt', 'hello')

      result = sweep

      assert_equal 1, result.ingested
      asset = Dam::Asset.sole
      assert_equal 'minutes.txt', asset.filename
      assert_equal 'minutes', asset.title
      assert_equal @location, asset.storage_location
      assert_equal 'Watch folder', asset.uploaded_by_name
      assert_equal 'hello', asset.file.download
      assert_equal @location.storage_service_name, asset.file.blob.service_name
      assert_predicate @drop.join(Dam::WatchFolderIngest::INGESTED, 'minutes.txt'), :file?
      assert_not @drop.join('minutes.txt').exist?
    end

    test 'the stored file lands under the location root' do
      drop('minutes.txt', 'hello')

      sweep

      stored = Dir.glob(File.join(@location.root, '**', '*')).select { |path| File.file?(path) }

      assert_equal 1, stored.size
      assert_equal 'hello', File.read(stored.first)
    end

    test 'records the ingest on the Jobs feed' do
      drop('minutes.txt', 'hello')

      sweep

      job = Dam::Job.of_type('ingest').sole

      assert_equal 'succeeded', job.status
      assert_equal Dam::Asset.sole, job.subject
      assert_match(/from #{Regexp.escape(@location.watch_path)}/, job.log)
    end

    test 'leaves a file that is still being written, and files it is told to ignore' do
      drop('half-copied.txt', 'part', age: 5.seconds)
      drop('.hidden.txt', 'hidden')
      drop('report.pdf.part', 'partial')

      result = sweep

      assert_equal 0, result.ingested
      assert_equal 0, Dam::Asset.count
      assert_predicate @drop.join('half-copied.txt'), :file?
      assert_predicate @drop.join('.hidden.txt'), :file?
    end

    test 'a second drop of the same name keeps both originals' do
      drop('minutes.txt', 'first')
      sweep
      drop('minutes.txt', 'second')
      sweep

      kept = @drop.join(Dam::WatchFolderIngest::INGESTED).children.map { |path| File.read(path) }

      assert_equal %w[first second], kept.sort
      assert_equal 2, Dam::Asset.count
    end

    test 'a file that cannot be ingested moves to _failed with the reason on its job' do
      drop('minutes.txt', 'hello')

      invalid = Dam::Asset.new(status: 'nowhere near a status')
      Dam::Asset.stub(:new, invalid) { sweep }

      assert_equal 0, Dam::Asset.count
      assert_predicate @drop.join(Dam::WatchFolderIngest::FAILED, 'minutes.txt'), :file?

      job = Dam::Job.of_type('ingest').sole

      assert_equal 'failed', job.status
      assert_equal @location, job.subject
      assert_match(/Status/i, job.error_message)
    end

    private

    def sweep = Dam::WatchFolderIngest.for_location(@location.reload).call

    # Dropped files are aged past the settle time unless a test is about a
    # file that is still arriving.
    def drop(name, body, age: 5.minutes)
      FileUtils.mkdir_p(@drop)
      path = @drop.join(name)
      File.write(path, body)
      FileUtils.touch(path, mtime: age.ago.to_time)
      path
    end
  end
end
