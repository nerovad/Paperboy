# frozen_string_literal: true

require 'test_helper'

module Dam
  module ResourceSpace
    # What an imported asset is called. ResourceSpace titled 882 stock photos
    # with a bare id, and a grid of numbers is no use to anybody looking for a
    # picture.
    class ImportTitlesTest < ActiveSupport::TestCase
      include BundleBuilder

      setup do
        ActiveStorage::Attachment.delete_all
        ActiveStorage::Blob.delete_all
        Dam::Asset.delete_all
        Dam::StorageLocation.delete_all
        @root = Pathname(Dir.mktmpdir('rs-titles'))
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

      test 'a bare-number title gives way to the original filename' do
        assert_equal 'Mom with daughter in market iStock 1142533480',
                     title_for('1142533480', 'Mom_with_daughter_in_market_iStock-1142533480.jpg')
      end

      test 'a real title is kept as ResourceSpace had it' do
        assert_equal 'Whale Shark Test', title_for('Whale Shark Test', 'whale_shark.mp4')
      end

      test 'a title with a number in it is still a real title' do
        assert_equal 'Airport 2024', title_for('Airport 2024', 'airport.jpg')
      end

      test 'a bare-number title with no filename to fall back on is kept' do
        assert_equal '1142533480', title_for('1142533480', nil)
      end

      private

      def title_for(title, original_filename)
        bundle = build_bundle(@root.join('bundle'),
                              resources: [exported_resource(1, title: title, file_path: 'a.jpg',
                                                               original_filename: original_filename)])
        Import.new(location: @location, bundle: bundle, sync_base: @sync.to_s).call
        Dam::Asset.sole.title
      end
    end
  end
end
