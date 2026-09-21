# frozen_string_literal: true

require 'test_helper'

module Dam
  module ResourceSpace
    # The import reads ResourceSpace's catalogue and leaves its files alone.
    # The catalogue is a stand-in here: what matters is what the import does
    # with what it is told, not that MySQL answers.
    class ImportTest < ActiveSupport::TestCase
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

      test 'a resource in the filestore becomes a referenced asset with its catalogue title' do
        write(@filestore.join('1/1/811_abc.jpg'), 'original bytes')
        write(@filestore.join('1/1/811scr_def.jpg'), 'screen preview')
        write(@filestore.join('1/1/811thm_ghi.jpg'), 'thumb preview')

        result = import(resources: [resource(811, extension: 'jpg')],
                        metadata: { 811 => { 'title' => 'Harbour at dawn', 'keywords' => 'sea, boats' } })

        assert_equal 1, result.imported
        assert_equal 1, result.adopted

        asset = Dam::Asset.sole

        assert_equal 'Harbour at dawn', asset.title
        assert_equal '811', asset.external_ref
        assert_predicate asset, :referenced?
        assert_equal @filestore.join('1/1/811_abc.jpg').to_s, asset.source_path
        assert_not asset.file.attached?
        assert_equal 'screen preview', asset.proxy.download
        assert_equal 'thumb preview', asset.thumbnail.download
        assert_equal 'ready', asset.derivative_state
        assert_equal 'sea, boats', asset.metadata_hash['keywords']
      end

      test 'a resource whose original is under the sync folder is found there' do
        write(@sync.join('Icons/logo.png'), 'synced bytes')

        result = import(resources: [resource(9, extension: 'png', file_path: 'Icons/logo.png')],
                        sync_base: @sync)

        assert_equal 1, result.imported
        assert_equal @sync.join('Icons/logo.png').to_s, Dam::Asset.sole.source_path
      end

      test 'a resource whose original is nowhere is reported rather than catalogued' do
        importer = build(resources: [resource(7, file_path: 'Gone/missing.jpg')], sync_base: @sync)
        result = importer.call

        assert_equal 0, result.imported
        assert_equal 1, result.missing
        assert_equal 0, Dam::Asset.count
        assert_equal [{ ref: 7, path: 'Gone/missing.jpg' }], importer.unresolved
      end

      test 'running it twice updates rather than duplicating' do
        write(@filestore.join('1/811_abc.jpg'), 'bytes')
        rows = [resource(811, extension: 'jpg')]

        import(resources: rows, metadata: { 811 => { 'title' => 'First name' } })
        result = import(resources: rows, metadata: { 811 => { 'title' => 'Renamed later' } })

        assert_equal 0, result.imported
        assert_equal 1, result.updated
        assert_equal 1, Dam::Asset.count
        assert_equal 'Renamed later', Dam::Asset.sole.title
      end

      test 'a resource with no preview to adopt has one queued instead' do
        write(@filestore.join('1/500_abc.jpg'), 'bytes')

        result = nil
        assert_enqueued_with(job: Dam::BuildDerivativesJob) do
          result = import(resources: [resource(500, extension: 'jpg')])
        end

        assert_equal 0, result.adopted
        assert_equal 'pending', Dam::Asset.sole.derivative_state
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
