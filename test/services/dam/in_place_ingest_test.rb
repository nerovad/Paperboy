# frozen_string_literal: true

require 'test_helper'

module Dam
  # Reading somebody else's library: everything stays where it is, and a second
  # scan must not ingest it all again.
  class InPlaceIngestTest < ActiveSupport::TestCase
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
                                               ingest_mode: 'leave')
      @share = Pathname(@location.watch_path)
    end

    teardown do
      ENV['PAPERBOY_DAM_ROOTS'] = @previous_roots
      FileUtils.rm_rf(@allowed)
    end

    test 'reads a subfolder without moving or renaming anything' do
      file = drop('photos/team/summer.jpg', 'jpeg bytes')

      result = sweep

      assert_equal 1, result.ingested
      assert_predicate file, :file?
      assert_equal 'jpeg bytes', File.read(file)
      assert_equal [], @share.children.map { |path| path.basename.to_s } - ['photos']

      asset = Dam::Asset.sole

      assert_equal 'summer.jpg', asset.filename
      assert_equal file.to_s, asset.source_path
      assert_equal 'jpeg bytes', asset.file.download
    end

    # The scan resumes after its cursor, so the pass following a full one has
    # nothing left to look at and clears the cursor. Only the pass after that
    # walks the tree again — and finds every file already held.
    test 'later scans hold what they already have rather than ingesting it twice' do
      drop('a.jpg', 'one')
      drop('b.jpg', 'two')

      assert_equal 2, sweep.ingested

      emptied = sweep

      assert_equal 0, emptied.ingested
      assert_nil @location.reload.scan_cursor

      rewalked = sweep

      assert_equal 0, rewalked.ingested
      assert_equal 2, rewalked.skipped
      assert_equal 2, Dam::Asset.count
    end

    test 'a file added later is picked up on the next scan' do
      drop('a.jpg', 'one')
      sweep

      drop('b.jpg', 'two')

      assert_equal 1, sweep.ingested
      assert_equal %w[a.jpg b.jpg], Dam::Asset.order(:filename).pluck(:filename)
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

    test 'a batch is capped, and the next scan resumes after the cursor' do
      5.times { |index| drop("photo#{index}.jpg", "bytes #{index}") }

      with_batch_size(2) do
        assert_equal 2, sweep.ingested
        assert_equal @share.join('photo1.jpg').to_s, @location.reload.scan_cursor

        assert_equal 2, sweep.ingested
        assert_equal 1, sweep.ingested
        assert_equal @share.join('photo4.jpg').to_s, @location.reload.scan_cursor

        # The pass that finds nothing after the cursor puts it back to the top.
        assert_equal 0, sweep.ingested
      end

      assert_equal 5, Dam::Asset.count
      assert_nil @location.reload.scan_cursor
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
