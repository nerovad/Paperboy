# frozen_string_literal: true

require 'test_helper'

module Dam
  module ResourceSpace
    # What the import does about the picture the library will show: adopt the
    # one ResourceSpace made, or queue one to be built when it made none.
    class ImportPreviewsTest < ActiveSupport::TestCase
      include ActiveJob::TestHelper
      include BundleBuilder

      setup do
        ActiveStorage::Attachment.delete_all
        ActiveStorage::Blob.delete_all
        Dam::Asset.delete_all
        Dam::StorageLocation.delete_all
        @root = Pathname(Dir.mktmpdir('rs-previews'))
        @previous_roots = ENV.fetch('PAPERBOY_DAM_ROOTS', nil)
        ENV['PAPERBOY_DAM_ROOTS'] = @root.realpath.to_s
        @sync = @root.join('graphics')
        FileUtils.mkdir_p(@sync)
        File.write(@sync.join('a.jpg'), 'bytes')
        @location = Dam::StorageLocation.create!(label: 'ResourceSpace', kind: 'disk',
                                                 root: @root.join('library').to_s)
      end

      teardown do
        ENV['PAPERBOY_DAM_ROOTS'] = @previous_roots
        FileUtils.rm_rf(@root)
      end

      test 'a preview ResourceSpace made is adopted, and nothing is queued' do
        bundle = build_bundle(@root.join('bundle'),
                              resources: [exported_resource(1, file_path: 'a.jpg', proxy: 'previews/1-proxy.jpg',
                                                               thumbnail: 'previews/1-thumbnail.jpg')],
                              files: { 'previews/1-proxy.jpg' => 'proxy', 'previews/1-thumbnail.jpg' => 'thumb' })

        assert_no_enqueued_jobs(only: Dam::BuildDerivativesJob) do
          assert_equal 1, import(bundle).adopted
        end
        assert_equal %w[proxy thumb], [Dam::Asset.sole.proxy.download, Dam::Asset.sole.thumbnail.download]
      end

      test 'with nothing to adopt, one is queued to be built' do
        bundle = build_bundle(@root.join('bundle'), resources: [exported_resource(1, file_path: 'a.jpg')])

        assert_enqueued_with(job: Dam::BuildDerivativesJob) do
          assert_equal 0, import(bundle).adopted
        end
      end

      private

      def import(bundle) = Import.new(location: @location, bundle: bundle, sync_base: @sync.to_s).call
    end
  end
end
