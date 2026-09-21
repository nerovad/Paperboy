# frozen_string_literal: true

require 'test_helper'

module Dam
  # What an in-place scan of somebody else's library declines to take, and what
  # it remembers about the files it could not.
  class InPlaceScanRulesTest < ActiveSupport::TestCase
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
      @location = Dam::StorageLocation.create!(label: 'Share', kind: 'disk',
                                               root: @allowed.join('library').to_s,
                                               watch_path: @allowed.join('share').to_s,
                                               ingest_mode: 'reference')
      @share = Pathname(@location.watch_path)
    end

    teardown do
      ENV['PAPERBOY_DAM_ROOTS'] = @previous_roots
      FileUtils.rm_rf(@allowed)
    end

    test 'only the accepted formats are read, and the rest are passed over silently' do
      @location.update!(accepted_formats: 'jpg, png')
      drop('keep.jpg', 'image')
      drop('skip.json', '{}')
      drop('skip.txt', 'notes')

      result = sweep

      assert_equal 1, result.ingested
      assert_equal 0, result.failed
      assert_equal ['keep.jpg'], Dam::Asset.pluck(:filename)
      assert_empty Dam::Job.where(status: 'failed')
    end

    test 'filenames matching the skip patterns are passed over' do
      @location.update!(ignore_patterns: '*thm_*, *scr_*')
      drop('811_abc.jpg', 'original')
      drop('811thm_def.jpg', 'thumbnail')
      drop('811scr_ghi.jpg', 'screen size')

      assert_equal 1, sweep.ingested
      assert_equal ['811_abc.jpg'], Dam::Asset.pluck(:filename)
    end

    test 'an empty file is not an asset' do
      drop('empty.jpg', '')
      drop('real.jpg', 'bytes')

      assert_equal 1, sweep.ingested
      assert_equal ['real.jpg'], Dam::Asset.pluck(:filename)
      assert_empty Dam::IngestFailure.all
    end

    test 'a file that cannot be ingested is remembered and not retried' do
      drop('broken.jpg', 'bytes')
      Dam::Asset.stub(:new, Dam::Asset.new(status: 'nowhere near a status')) { sweep }

      failure = Dam::IngestFailure.sole

      assert_equal @share.join('broken.jpg').to_s, failure.source_path
      assert_match(/Status/i, failure.reason)
      assert_equal 1, Dam::Job.where(status: 'failed').count

      # The next pass walks it again and leaves it alone rather than logging
      # a second failure for the same file.
      sweep
      sweep

      assert_equal 1, Dam::IngestFailure.count
      assert_equal 1, Dam::Job.where(status: 'failed').count
    end

    private

    def sweep = Dam::WatchFolderIngest.for_location(@location.reload).call

    # remove_const first, so reassigning does not warn.
    def with_batch_size(size)
      original = Dam::WatchFolderIngest::BATCH_SIZE
      swap_batch_size(size)
      yield
    ensure
      swap_batch_size(original)
    end

    def swap_batch_size(size)
      Dam::WatchFolderIngest.send(:remove_const, :BATCH_SIZE)
      Dam::WatchFolderIngest.const_set(:BATCH_SIZE, size)
    end

    def drop(relative, body, age: 5.minutes)
      path = @share.join(relative)
      FileUtils.mkdir_p(path.dirname)
      File.write(path, body)
      FileUtils.touch(path, mtime: age.ago.to_time)
      path
    end
  end
end
