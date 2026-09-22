# frozen_string_literal: true

require 'test_helper'

module Dam
  module ResourceSpace
    # Importing an export on the DAM's own server: originals that only
    # ResourceSpace held are stored, ones on the graphics share are
    # referenced, and nothing needs ResourceSpace to still be running.
    class ImportTest < ActiveSupport::TestCase
      include ActiveJob::TestHelper
      include BundleBuilder

      setup do
        ActiveStorage::Attachment.delete_all
        ActiveStorage::Blob.delete_all
        Dam::CollectionAsset.delete_all
        Dam::Collection.delete_all
        Dam::Job.delete_all
        Dam::MetadataValue.delete_all
        Dam::Asset.delete_all
        Dam::StorageLocation.delete_all
        Dam::MetadataField.where(key: %w[agency extracted_text]).delete_all

        @root = Pathname(Dir.mktmpdir('rs-import'))
        @previous_roots = ENV.fetch('PAPERBOY_DAM_ROOTS', nil)
        ENV['PAPERBOY_DAM_ROOTS'] = @root.realpath.to_s
        @sync = @root.join('graphics')
        FileUtils.mkdir_p(@sync)
        @location = Dam::StorageLocation.create!(label: 'ResourceSpace', kind: 'disk',
                                                 root: @root.join('library').to_s)
      end

      teardown do
        ENV['PAPERBOY_DAM_ROOTS'] = @previous_roots
        FileUtils.rm_rf(@root)
      end

      test 'an original that lived inside ResourceSpace is stored in the DAM' do
        bundle = bundle_with(
          [exported_resource(811, title: 'Harbour', original: 'originals/811/harbour.jpg',
                                  original_filename: 'harbour.jpg', proxy: 'previews/811-proxy.jpg')],
          files: { 'originals/811/harbour.jpg' => 'the only copy', 'previews/811-proxy.jpg' => 'proxy' }
        )

        result = import(bundle)
        asset = Dam::Asset.sole

        assert_equal [1, 1, 0], [result.imported, result.stored, result.referenced]
        assert_predicate asset, :stored?
        assert_equal 'the only copy', asset.file.download
        assert_equal 'harbour.jpg', asset.filename
        assert_equal 'Harbour', asset.title
        assert_equal 'proxy', asset.proxy.download
        assert_equal 'ready', asset.derivative_state
      end

      test 'an original on the graphics share is referenced where it stands' do
        File.write(@sync.join('logo.png'), 'shared bytes')
        bundle = bundle_with([exported_resource(9, file_path: 'logo.png')])

        result = import(bundle)
        asset = Dam::Asset.sole

        assert_equal [1, 0], [result.referenced, result.stored]
        assert_predicate asset, :referenced?
        assert_equal @sync.join('logo.png').to_s, asset.source_path
        assert_not asset.file.attached?
      end

      test 'a resource whose original is nowhere is reported, not catalogued' do
        importer = importer_for(bundle_with([exported_resource(7, file_path: 'Gone/missing.jpg')]))
        result = importer.call

        assert_equal 1, result.missing
        assert_equal 0, Dam::Asset.count
        assert_equal [{ ref: 7, path: 'Gone/missing.jpg' }], importer.unresolved
      end

      test 'every exported field is created, and its values land on the asset' do
        File.write(@sync.join('a.jpg'), 'bytes')
        bundle = bundle_with(
          [exported_resource(1, file_path: 'a.jpg', description: 'A description',
                                metadata: { 'agency' => 'GSA', 'extracted_text' => 'words' })],
          fields: [{ 'key' => 'agency', 'label' => 'Agency', 'field_type' => 'text' },
                   { 'key' => 'extracted_text', 'label' => 'Extracted text', 'field_type' => 'text' }]
        )

        import(bundle)
        asset = Dam::Asset.sole

        assert_equal 'A description', asset.description
        assert_equal({ 'agency' => 'GSA', 'extracted_text' => 'words' }, asset.metadata_hash)
        assert_equal ['Agency', 'Extracted text'],
                     Dam::MetadataField.where(key: %w[agency extracted_text]).order(:key).pluck(:label)
      end

      test 'running it twice updates rather than storing a second copy' do
        bundle = bundle_with([exported_resource(811, original: 'originals/811/a.jpg')],
                             files: { 'originals/811/a.jpg' => 'bytes' })

        import(bundle)
        blobs = ActiveStorage::Blob.count
        second = import(bundle)

        assert_equal [0, 1], [second.imported, second.updated]
        assert_equal 1, Dam::Asset.count
        assert_equal blobs, ActiveStorage::Blob.count
      end

      test 'a dry run counts and writes nothing' do
        File.write(@sync.join('a.jpg'), 'bytes')

        result = import(bundle_with([exported_resource(1, file_path: 'a.jpg')]), dry_run: true)

        assert_equal 1, result.imported
        assert_equal 0, Dam::Asset.count
      end

      private

      def bundle_with(resources, **options)
        build_bundle(@root.join('bundle'), resources: resources, **options)
      end

      def importer_for(bundle, dry_run: false)
        Import.new(location: @location, bundle: bundle, sync_base: @sync.to_s, dry_run: dry_run)
      end

      def import(bundle, **options) = importer_for(bundle, **options).call
    end
  end
end
