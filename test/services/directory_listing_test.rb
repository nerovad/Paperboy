# frozen_string_literal: true

require 'test_helper'

class DirectoryListingTest < ActiveSupport::TestCase
  test 'lists folders before files and includes file metadata' do
    Dir.mktmpdir do |directory|
      FileUtils.mkdir_p(File.join(directory, 'Archive'))
      File.write(File.join(directory, 'ovs-2.xml'), 'xml')
      File.write(File.join(directory, 'ovs-1.xml'), 'data')

      entries = DirectoryListing.new(directory).call

      assert_equal ['Archive', 'ovs-1.xml', 'ovs-2.xml'], entries.map(&:name)
      assert_predicate entries.first, :directory
      assert_equal 4, entries.second.size
      assert_instance_of Time, entries.second.modified
    end
  end

  test 'reports an unavailable folder' do
    error = assert_raises(DirectoryListing::Unavailable) do
      DirectoryListing.new('/folder/that/does/not/exist').call
    end

    assert_equal 'The folder is currently unavailable.', error.message
  end
end
