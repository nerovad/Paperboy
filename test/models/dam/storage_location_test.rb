# frozen_string_literal: true

require 'test_helper'

module Dam
  class StorageLocationTest < ActiveSupport::TestCase
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

    test 'a root inside the allowed folders is accepted and created' do
      location = build(root: @allowed.join('photos').to_s)

      assert_predicate location, :valid?
      assert location.save
      assert_predicate @allowed.join('photos'), :directory?
    end

    test 'a root outside the allowed folders is refused' do
      location = build(root: Dir.mktmpdir('elsewhere'))

      assert_not location.valid?
      assert_match(/must be inside/, location.errors[:root].to_sentence)
    end

    test 'a symlink out of the allowed folders does not smuggle a root back in' do
      outside = Pathname(Dir.mktmpdir('elsewhere'))
      File.symlink(outside, @allowed.join('link'))

      location = build(root: @allowed.join('link').to_s)

      assert_not location.valid?
    ensure
      FileUtils.rm_rf(outside)
    end

    test 'only a filesystem kind with a root gets a service of its own' do
      location = create(root: @allowed.join('photos').to_s)

      assert_equal "dam_location_#{location.id}_#{digest_of(location.root)}", location.storage_service_name
      assert_equal location.root, location.storage_path
      assert_nil create(label: 'Default', root: nil).storage_service_name
      assert_nil create(label: 'Bucket', kind: 's3', root: @allowed.join('bucket').to_s).storage_service_name
    end

    test 'the service name resolves to a disk service rooted at the location' do
      location = create(root: @allowed.join('photos').to_s)

      service = ActiveStorage::Blob.services.fetch(location.storage_service_name)

      assert_equal location.root, service.root.to_s
      assert_nil Dam::StorageLocation.service_for("dam_location_#{location.id}_000000000000")
    end

    test 'a root may change until files are stored under it, and not after' do
      location = create(root: @allowed.join('photos').to_s)

      assert location.update(root: @allowed.join('moved').to_s)

      store_blob(location)

      assert_not location.update(root: @allowed.join('again').to_s)
      assert_match(/cannot change while files are stored/, location.errors[:root].to_sentence)
      assert location.reload.update(label: 'Renamed')
    end

    test 'a location whose files are still in its root cannot be removed' do
      location = create(root: @allowed.join('photos').to_s)
      store_blob(location)

      assert_not location.destroy
      assert_match(/still stored in its root/, location.errors[:base].to_sentence)
    end

    test 'a root outside the allowed folders closes the location to uploads' do
      location = create(root: @allowed.join('photos').to_s)
      ENV['PAPERBOY_DAM_ROOTS'] = Dir.mktmpdir('other-roots')

      assert_equal 'outside the allowed storage folders', location.refusal_reason
      assert_not location.accepts_uploads?
    end

    private

    def build(**attributes)
      Dam::StorageLocation.new({ label: 'Photos', kind: 'disk' }.merge(attributes))
    end

    def create(**attributes) = build(**attributes).tap(&:save!)

    def digest_of(root) = Digest::SHA256.hexdigest(File.expand_path(root))[0, 12]

    def store_blob(location)
      ActiveStorage::Blob.create!(key: ActiveStorage::Blob.generate_unique_secure_token(length: 28),
                                  filename: 'a.txt', byte_size: 1, checksum: 'x',
                                  content_type: 'text/plain',
                                  service_name: location.storage_service_name)
    end
  end
end
