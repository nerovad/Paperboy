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

  test 'reports an unavailable reference' do
    error = assert_raises(DirectoryListing::Unavailable) do
      DirectoryListing.new('/folder/that/does/not/exist').call
    end

    assert_equal 'The reference is currently unavailable.', error.message
  end

  test 'lists a single referenced file' do
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'document_automation.xlsx')
      File.write(path, 'workbook')

      entries = DirectoryListing.new(path).call

      assert_equal ['document_automation.xlsx'], entries.map(&:name)
      assert_not_predicate entries.first, :directory
      assert_equal 8, entries.first.size
    end
  end

  test 'lists a file beneath a shortcut-backed reference' do
    Dir.mktmpdir do |directory|
      shortcut = Pathname.new(directory).join('outputs.lnk').tap { |path| path.write('shortcut') }
      store = Object.new
      store.define_singleton_method(:entries) do |prefix = nil|
        if prefix == '01_Download'
          [{ name: 'agencies.xlsx', directory: false, size: 8,
             modified_at: Time.utc(2026, 9, 24) }]
        else
          [{ name: '01_Download', directory: true, modified_at: Time.utc(2026, 9, 24) }]
        end
      end

      Paperboy::FileStore.stub(:for, store) do
        entries = DirectoryListing.new("#{shortcut}/01_Download/agencies.xlsx").call

        assert_equal ['agencies.xlsx'], entries.map(&:name)
        assert_equal 8, entries.first.size
      end
    end
  end
end
