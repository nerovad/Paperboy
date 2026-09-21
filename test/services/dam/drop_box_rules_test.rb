# frozen_string_literal: true

require 'test_helper'

# What a drop box refuses, and when it stops: the rules around the sweep
# rather than the sweep itself.

module Dam
  class DropBoxRulesTest < ActiveSupport::TestCase
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

    test 'a format the location does not take is moved aside with the reason' do
      @location.update!(accepted_formats: 'pdf')
      drop('minutes.txt', 'hello')

      result = sweep

      assert_equal 1, result.failed
      assert_equal 0, Dam::Asset.count
      assert_predicate @drop.join(Dam::WatchFolderIngest::FAILED, 'minutes.txt'), :file?
      assert_match(/TXT is not one of the formats/, Dam::Job.of_type('ingest').sole.error_message)
    end

    test 'sweeps nothing while the location is closed to uploads' do
      drop('minutes.txt', 'hello')
      @location.update!(read_only: true)

      assert_equal 0, sweep.ingested
      assert_predicate @drop.join('minutes.txt'), :file?
    end

    test 'sweep_all covers every watching location and skips the rest' do
      drop('minutes.txt', 'hello')
      Dam::StorageLocation.create!(label: 'Idle', kind: 'disk',
                                   watch_path: @allowed.join('idle').to_s)

      assert_equal [1], Dam::WatchFolderIngest.sweep_all.map(&:ingested)
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
