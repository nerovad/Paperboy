# frozen_string_literal: true

require 'test_helper'

module Dam
  module ResourceSpace
    # A bundle arrives by scp from another machine, so it is input like any
    # other: a path inside it that climbs out is refused, not read.
    class BundleTest < ActiveSupport::TestCase
      include BundleBuilder

      setup { @root = Pathname(Dir.mktmpdir('rs-bundle')) }
      teardown { FileUtils.rm_rf(@root) }

      test 'resolves a file the bundle carries' do
        bundle = build_bundle(@root, files: { 'previews/1-proxy.jpg' => 'bytes' })

        assert_equal 'bytes', bundle.path('previews/1-proxy.jpg').read
      end

      test 'a named file that never arrived is nil, not an error' do
        assert_nil build_bundle(@root).path('previews/1-proxy.jpg')
      end

      test 'a path that climbs out of the bundle is refused' do
        bundle = build_bundle(@root)

        assert_raises(Bundle::Invalid) { bundle.path('../../etc/passwd') }
        assert_raises(Bundle::Invalid) { bundle.path('/etc/passwd') }
      end

      test 'a folder with no export in it says so' do
        error = assert_raises(Bundle::Invalid) { Bundle.new(@root) }

        assert_match(/catalog\.json is missing/, error.message)
      end

      test 'an export in a format this import does not read is refused' do
        File.write(@root.join('catalog.json'), JSON.generate('format' => 99))

        assert_raises(Bundle::Invalid) { Bundle.new(@root) }
      end
    end
  end
end
