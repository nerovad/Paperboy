# frozen_string_literal: true

require 'test_helper'
require 'active_storage/service/disk_service'

class LegacyStorageAdoptionTest < ActiveSupport::TestCase
  setup do
    @legacy = Pathname(Dir.mktmpdir('legacy-storage'))
    @root = Pathname(Dir.mktmpdir('env-storage'))
    @service = ActiveStorage::Service::DiskService.new(root: @root.to_s)
  end

  teardown do
    FileUtils.rm_rf([@legacy, @root])
  end

  test 'copies a referenced legacy file into the environment root and leaves the original' do
    key = local_blob.key
    legacy_file = write_legacy(key, 'bytes')

    result = adoption.call

    assert_equal 1, result.copied
    assert_equal 'bytes', File.read(@service.path_for(key))
    assert_predicate legacy_file, :exist?
  end

  test 'is idempotent and reports keys with no file anywhere' do
    present = local_blob
    write_legacy(present.key, 'bytes')
    absent = local_blob

    adoption.call
    result = adoption.call

    assert_equal 0, result.copied
    assert_equal 1, result.present
    assert_equal [absent.key], result.missing
  end

  test 'ignores blobs stored on another service' do
    blob = local_blob(service_name: 'test')
    write_legacy(blob.key, 'bytes')

    result = adoption.call

    assert_equal 0, result.copied
    assert_empty result.missing
  end

  test 'does nothing when the environment root is still the legacy folder' do
    write_legacy(local_blob.key, 'bytes')

    result = LegacyStorageAdoption.new(legacy_root: @legacy,
                                       service: ActiveStorage::Service::DiskService.new(root: @legacy.to_s)).call

    assert_equal 0, result.copied
  end

  private

  def adoption = LegacyStorageAdoption.new(legacy_root: @legacy, service: @service)

  def local_blob(service_name: 'local')
    ActiveStorage::Blob.create!(key: ActiveStorage::Blob.generate_unique_secure_token(length: 28),
                                filename: 'a.txt', byte_size: 5, checksum: 'x',
                                content_type: 'text/plain', service_name: service_name)
  end

  def write_legacy(key, bytes)
    path = @legacy.join(key[0..1], key[2..3], key)
    FileUtils.mkdir_p(path.dirname)
    File.write(path, bytes)
    path
  end
end
