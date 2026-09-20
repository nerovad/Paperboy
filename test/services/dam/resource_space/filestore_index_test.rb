# frozen_string_literal: true

require 'test_helper'

module Dam
  module ResourceSpace
    # ResourceSpace scrambles its folder names with a key from its config, so
    # the index is built by reading the filestore rather than by computing it.
    class FilestoreIndexTest < ActiveSupport::TestCase
      setup do
        @root = Pathname(Dir.mktmpdir('filestore'))
      end

      teardown { FileUtils.rm_rf(@root) }

      test 'finds an original and its previews wherever the tree puts them' do
        write('1/1/8_eb12442bb5aba61/811_0cc6af587abbbc0.jpg')
        write('1/1/8_eb12442bb5aba61/811scr_a8869a6bfe3681c.jpg')
        write('1/1/8_eb12442bb5aba61/811thm_a384db14dd8e6ac.jpg')

        entry = index[811]

        assert_match(/811_0cc6af587abbbc0\.jpg\z/, entry.original.to_s)
        assert_match(/811scr_/, entry.proxy.to_s)
        assert_match(/811thm_/, entry.thumbnail.to_s)
      end

      test 'prefers the largest preview available as the proxy' do
        write('0/1/900col_a.jpg')
        write('0/1/900thm_b.jpg')

        assert_match(/900col_/, index[900].proxy.to_s)

        write('0/1/900hpr_c.jpg')

        assert_match(/900hpr_/, index[900].proxy.to_s)
      end

      test 'a resource with previews but no original is still indexed' do
        write('2/2/222scr_a.jpg')

        entry = index[222]

        assert_nil entry.original
        assert_predicate entry.proxy, :present?
      end

      test 'empty files and names that are not ResourceSpace files are ignored' do
        write('3/333_abc.jpg', body: '')
        write('3/notes.txt')

        built = index

        assert_empty built.keys
      end

      private

      def index = FilestoreIndex.new(@root).build

      def write(relative, body: 'bytes')
        path = @root.join(relative)
        FileUtils.mkdir_p(path.dirname)
        File.write(path, body)
        path
      end
    end
  end
end
