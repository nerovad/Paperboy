# frozen_string_literal: true

require 'test_helper'

module Dam
  module ResourceSpace
    # Running the import without committing to it: a dry run that writes
    # nothing, and a limit for a first pass at somebody's whole library.
    class ImportRunModesTest < ActiveSupport::TestCase
      include ActiveJob::TestHelper

      setup do
        ActiveStorage::Attachment.delete_all
        ActiveStorage::Blob.delete_all
        Dam::Job.delete_all
        Dam::Asset.delete_all
        Dam::StorageLocation.delete_all
        Dam::MetadataField.where(key: %w[keywords caption]).delete_all

        @allowed = Pathname(Dir.mktmpdir('dam-roots'))
        @previous_roots = ENV.fetch('PAPERBOY_DAM_ROOTS', nil)
        @previous_filestore = ENV.fetch('RS_FILESTORE', nil)
        ENV['PAPERBOY_DAM_ROOTS'] = @allowed.realpath.to_s

        @filestore = @allowed.join('filestore')
        @sync = @allowed.join('sync')
        ENV['RS_FILESTORE'] = @filestore.to_s
        FileUtils.mkdir_p([@filestore, @sync])

        @location = Dam::StorageLocation.create!(label: 'ResourceSpace', kind: 'disk',
                                                 root: @allowed.join('library').to_s,
                                                 watch_path: @filestore.to_s,
                                                 ingest_mode: 'off')
        Dam::MetadataField.create!(key: 'keywords', label: 'Keywords', field_type: 'text')
      end

      teardown do
        ENV['PAPERBOY_DAM_ROOTS'] = @previous_roots
        ENV['RS_FILESTORE'] = @previous_filestore
        FileUtils.rm_rf(@allowed)
      end

      test 'a dry run reports what it would do and writes nothing' do
        write(@filestore.join('1/811_abc.jpg'), 'bytes')

        result = import(resources: [resource(811, extension: 'jpg')], dry_run: true)

        assert_equal 1, result.imported
        assert_equal 0, Dam::Asset.count
      end

      test 'the import stops at the limit it is given' do
        3.times { |index| write(@filestore.join("1/#{100 + index}_abc.jpg"), 'bytes') }
        rows = 3.times.map { |index| resource(100 + index, extension: 'jpg') }

        assert_equal 2, import(resources: rows, limit: 2).imported
      end

      private

      def resource(ref, extension: 'jpg', file_path: '')
        { 'ref' => ref, 'title' => '', 'resource_type' => 1, 'file_extension' => extension,
          'file_size' => 100, 'file_path' => file_path, 'creation_date' => '2024-03-01 10:00:00',
          'created_by' => 1, 'has_image' => 1 }
      end

      def build(resources:, metadata: {}, sync_base: nil, limit: nil, dry_run: false)
        Import.new(location: @location, sync_base: sync_base&.to_s,
                   catalog: Dam::ResourceSpace::FakeCatalog.new(resources: resources, metadata: metadata),
                   limit: limit, dry_run: dry_run)
      end

      def import(**options) = build(**options).call

      def write(path, body)
        FileUtils.mkdir_p(path.dirname)
        File.write(path, body)
        path
      end
    end
  end
end
