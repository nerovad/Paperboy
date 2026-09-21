# frozen_string_literal: true

require 'test_helper'

module Dam
  class StorageLocationWatchTest < ActiveSupport::TestCase
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
    end

    teardown do
      ENV['PAPERBOY_DAM_ROOTS'] = @previous_roots
      FileUtils.rm_rf(@allowed)
    end

    test 'a watch folder must be inside the allowed folders and apart from stored files' do
      location = create(root: @allowed.join('photos').to_s)

      location.watch_path = Dir.mktmpdir('elsewhere')

      assert_not location.valid?

      location.watch_path = @allowed.join('photos', 'drop').to_s

      assert_not location.valid?
      assert_match(/overlaps a folder the library stores files in/, location.errors[:watch_path].to_sentence)

      location.watch_path = @allowed.join('drop').to_s

      assert_predicate location, :valid?
    end

    test 'two locations cannot watch the same folder' do
      create(root: @allowed.join('photos').to_s, watch_path: @allowed.join('drop').to_s)
      second = build(label: 'Second', root: @allowed.join('video').to_s,
                     watch_path: @allowed.join('drop', 'inner').to_s)

      assert_not second.valid?
      assert_match(/watch folder/, second.errors[:watch_path].to_sentence)
    end

    test 'scanning lists only locations open for upload with a folder switched on' do
      watched = create(label: 'Watched', root: @allowed.join('photos').to_s,
                       watch_path: @allowed.join('drop').to_s, ingest_mode: 'move')
      create(label: 'Idle', watch_path: @allowed.join('idle').to_s)
      create(label: 'Closed', watch_path: @allowed.join('closed').to_s, ingest_mode: 'move',
             read_only: true)

      assert_equal [watched.id], Dam::StorageLocation.scanning.pluck(:id)
    end

    test 'scanning a folder needs the folder' do
      location = build(ingest_mode: 'move')

      assert_not location.valid?
      assert_match(/is needed to scan a folder/, location.errors[:watch_path].to_sentence)
    end

    test 'a format list is read whatever the separators and dots' do
      location = build(accepted_formats: '.jpg, png  MOV,.pdf')

      assert_equal %w[JPG PNG MOV PDF], location.accepted_format_list
      assert location.accepts_format?('.jpg')
      assert location.accepts_format?('mov')
      assert_not location.accepts_format?('doc')
    end

    # One letter should not decide whether half a camera's output is
    # cataloguable.
    test 'a format list covers the other spellings of the same format' do
      location = build(accepted_formats: 'jpg, tif, mpg')

      assert location.accepts_format?('jpeg')
      assert location.accepts_format?('.JPEG')
      assert location.accepts_format?('tiff')
      assert location.accepts_format?('mpeg')
      assert_not location.accepts_format?('png')
    end

    test 'the list may be written in either spelling' do
      assert build(accepted_formats: 'jpeg').accepts_format?('jpg')
      assert build(accepted_formats: 'tiff').accepts_format?('tif')
    end

    test 'a blank format list accepts everything' do
      location = build(accepted_formats: '  ')

      assert_empty location.accepted_format_list
      assert location.accepts_format?('anything')
    end

    private

    def build(**attributes)
      Dam::StorageLocation.new({ label: 'Photos', kind: 'disk' }.merge(attributes))
    end

    def create(**attributes) = build(**attributes).tap(&:save!)
  end
end
