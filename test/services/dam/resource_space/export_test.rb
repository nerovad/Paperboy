# frozen_string_literal: true

require 'test_helper'

module Dam
  module ResourceSpace
    # The export is what survives ResourceSpace being switched off, so what it
    # must carry is exactly what exists nowhere else: the catalogue, the
    # previews, and the originals that lived inside ResourceSpace's filestore.
    class ExportTest < ActiveSupport::TestCase
      setup do
        @root = Pathname(Dir.mktmpdir('rs-export'))
        @filestore = @root.join('filestore')
        @out = @root.join('bundle')
        FileUtils.mkdir_p(@filestore)
      end

      teardown { FileUtils.rm_rf(@root) }

      test 'carries the catalogue, the previews and the originals only ResourceSpace held' do
        write('1/811_abc.jpg', 'filestore original')
        write('1/811scr_def.jpg', 'screen preview')
        write('1/811thm_ghi.jpg', 'thumbnail')
        write('2/900scr_x.jpg', 'preview of a synced file')

        export(resources: [resource(811), resource(900, file_path: 'Icons/logo.png')],
               metadata: { 811 => { 'title' => 'Harbour', 'caption' => 'At dawn',
                                    'originalfilename' => 'harbour.jpg', 'owneragency' => 'GSA' } })

        filestore_copy = record(811)

        assert_equal 'Harbour', filestore_copy['title']
        assert_equal 'At dawn', filestore_copy['description']
        assert_equal 'originals/811/harbour.jpg', filestore_copy['original']
        assert_equal 'filestore original', @out.join(filestore_copy['original']).read
        assert_equal 'screen preview', @out.join(filestore_copy['proxy']).read
        assert_equal 'thumbnail', @out.join(filestore_copy['thumbnail']).read

        synced = record(900)

        assert_nil synced['original'], 'a file on the graphics share stays there'
        assert_equal 'Icons/logo.png', synced['file_path']
        assert_equal 'preview of a synced file', @out.join(synced['proxy']).read
      end

      test 'metadata is keyed the way the DAM names it, and the title is not metadata' do
        write('1/811_abc.jpg', 'bytes')

        export(resources: [resource(811)],
               metadata: { 811 => { 'title' => 'Harbour', 'caption' => 'At dawn',
                                    'assetdescription' => 'Beach_Theme_Images',
                                    'ownerdepartment' => 'Fleet', 'folderpath' => 'Boats/2024',
                                    'text' => 'extracted words', 'camera' => 'Nikon' } })

        assert_equal 'At dawn', record(811)['description']
        assert_equal({ 'category' => 'Beach_Theme_Images', 'department' => 'Fleet',
                       'folder_path' => 'Boats/2024', 'extracted_text' => 'extracted words',
                       'camera' => 'Nikon' },
                     record(811)['metadata'])
      end

      test 'every field in use becomes a DAM field, with dates as dates' do
        export(fields: [{ 'name' => 'title', 'title' => 'Title', 'type' => 0 },
                        { 'name' => 'owneragency', 'title' => 'Agency', 'type' => 3 },
                        { 'name' => 'date', 'title' => 'Date', 'type' => 4 },
                        { 'name' => 'lens', 'title' => 'Lens used', 'type' => 0 }])

        assert_equal [{ 'key' => 'agency', 'label' => 'Agency', 'field_type' => 'text' },
                      { 'key' => 'captured_on', 'label' => 'Captured on', 'field_type' => 'date' },
                      { 'key' => 'lens', 'label' => 'Lens used', 'field_type' => 'text' }],
                     catalog['fields']
      end

      test 'collections travel with their members in order' do
        export(collections: [{ 'ref' => 28, 'name' => 'Murals', 'description' => '',
                               'parent' => nil, 'resources' => [3, 1, 2] }])

        assert_equal [3, 1, 2], catalog['collections'].sole['resources']
      end

      test 'a second run copies nothing already in the bundle' do
        write('1/811_abc.jpg', 'filestore original')
        write('1/811scr_def.jpg', 'screen preview')
        rows = [resource(811)]

        first = export(resources: rows)
        second = export(resources: rows)

        assert_operator first.bytes, :>, 0
        assert_equal 0, second.bytes
        assert_equal 1, second.originals
      end

      private

      def resource(ref, file_path: '')
        { 'ref' => ref, 'title' => '', 'resource_type' => 1, 'file_extension' => 'jpg',
          'file_size' => 100, 'file_path' => file_path, 'creation_date' => '2024-03-01 10:00:00',
          'created_by' => 1, 'has_image' => 1 }
      end

      def export(resources: [], metadata: {}, fields: [], collections: [])
        catalog = FakeCatalog.new(resources: resources, metadata: metadata, fields: fields,
                                  collections: collections)
        Export.new(out: @out, catalog: catalog, filestore_root: @filestore).call
      end

      def catalog = JSON.parse(@out.join('catalog.json').read)

      def record(ref) = catalog['resources'].find { |row| row['ref'] == ref }

      def write(relative, body)
        path = @filestore.join(relative)
        FileUtils.mkdir_p(path.dirname)
        File.write(path, body)
      end
    end
  end
end
