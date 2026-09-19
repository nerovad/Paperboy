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

    test 'watching lists only locations open for upload with a folder switched on' do
      watched = create(label: 'Watched', root: @allowed.join('photos').to_s,
                       watch_path: @allowed.join('drop').to_s, watch_enabled: true)
      create(label: 'Idle', watch_path: @allowed.join('idle').to_s)
      create(label: 'Closed', watch_path: @allowed.join('closed').to_s, watch_enabled: true,
             read_only: true)

      assert_equal [watched.id], Dam::StorageLocation.watching.pluck(:id)
    end

    test 'watching a folder needs the folder' do
      location = build(watch_enabled: true)

      assert_not location.valid?
      assert_match(/is needed to watch a folder/, location.errors[:watch_path].to_sentence)
    end

    private

    def build(**attributes)
      Dam::StorageLocation.new({ label: 'Photos', kind: 'disk' }.merge(attributes))
    end

    def create(**attributes) = build(**attributes).tap(&:save!)
  end
end
