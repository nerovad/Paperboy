# frozen_string_literal: true

require 'test_helper'

module Dam
  # What a location will read a file from. An imported original is often
  # nowhere near the folder the location scans, so the allowed roots are the
  # boundary rather than the scanned folder.
  class StorageLocationSourceTest < ActiveSupport::TestCase
    setup do
      @allowed = Pathname(Dir.mktmpdir('dam-roots'))
      @elsewhere = Pathname(Dir.mktmpdir('elsewhere'))
      @previous_roots = ENV.fetch('PAPERBOY_DAM_ROOTS', nil)
      ENV['PAPERBOY_DAM_ROOTS'] = @allowed.realpath.to_s
      @location = Dam::StorageLocation.new(label: 'Share', kind: 'disk',
                                           watch_path: @allowed.join('scanned').to_s)
    end

    teardown do
      ENV['PAPERBOY_DAM_ROOTS'] = @previous_roots
      FileUtils.rm_rf([@allowed, @elsewhere])
    end

    test 'a file inside the allowed roots may be read, scanned folder or not' do
      assert @location.holds_source?(@allowed.join('scanned/photo.jpg'))
      assert @location.holds_source?(@allowed.join('imported/from/elsewhere.jpg'))
    end

    test 'a file outside the allowed roots may not' do
      assert_not @location.holds_source?(@elsewhere.join('secret.jpg'))
      assert_not @location.holds_source?('/etc/passwd')
    end

    test 'a path that climbs out of an allowed root is refused' do
      assert_not @location.holds_source?(@allowed.join('../../etc/passwd').to_s)
    end
  end
end
