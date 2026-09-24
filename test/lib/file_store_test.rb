# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require_relative '../../lib/paperboy/file_store'

class FileStoreTest < Minitest::Test
  def test_local_store_copies_and_removes_files
    Dir.mktmpdir do |directory|
      root = Pathname.new(directory).join('destination')
      source = Pathname.new(directory).join('source.txt').tap { |path| path.write('content') }
      store = Paperboy::FileStore.for(root)

      store.copy(source, 'nested/output.txt')

      assert store.exist?('nested/output.txt')
      assert_equal ['nested'], store.directories
      assert store.remove('nested/output.txt')
      refute store.exist?('nested/output.txt')
    end
  end

  def test_shortcut_store_creates_smb_client_only_when_used
    Dir.mktmpdir do |directory|
      shortcut_path = Pathname.new(directory).join('shipping.lnk').tap { |path| path.write('shortcut') }
      share = RecordingShare.new
      store = Paperboy::FileStore.for(
        shortcut_path,
        env: { 'SMB_USERNAME' => 'user', 'SMB_PASSWORD' => 'password' },
        shortcut_class: FakeShortcut,
        share_class: ->(**_options) { share }
      )

      assert_equal 0, share.calls.length
      store.copy('/tmp/source.zip', 'Mail.dat_50000001.zip')

      assert_equal [[:put, '/tmp/source.zip', 'Shipping\\Mail.dat_50000001.zip']], share.calls
    end
  end

  def test_shortcut_store_creates_missing_nested_remote_directories
    Dir.mktmpdir do |directory|
      shortcut_path = Pathname.new(directory).join('printers.lnk').tap { |path| path.write('shortcut') }
      share = DirectoryShare.new
      store = Paperboy::FileStore.for(
        shortcut_path,
        env: { 'SMB_USERNAME' => 'user', 'SMB_PASSWORD' => 'password' },
        shortcut_class: NestedFakeShortcut,
        share_class: ->(**_options) { share }
      )

      store.mkdir('Printer One/Queue A')

      assert_equal [
        [:list, 'Printers\\Printer One'],
        [:mkdir, 'Printers\\Printer One'],
        [:list, 'Printers\\Printer One\\Queue A'],
        [:mkdir, 'Printers\\Printer One\\Queue A']
      ], share.calls
    end
  end

  def test_shortcut_store_exposes_structured_remote_entries
    Dir.mktmpdir do |directory|
      shortcut_path = Pathname.new(directory).join('outputs.lnk').tap { |path| path.write('shortcut') }
      share = RecordingShare.new
      store = Paperboy::FileStore.for(
        shortcut_path,
        env: { 'SMB_USERNAME' => 'user', 'SMB_PASSWORD' => 'password' },
        shortcut_class: NestedFakeShortcut,
        share_class: ->(**_options) { share }
      )

      assert_equal ['Printer One'], store.directories
      assert_equal ['finished.pdf'], store.files
    end
  end

  def test_shortcut_store_reads_remote_entry_time
    Dir.mktmpdir do |directory|
      shortcut_path = Pathname.new(directory).join('outputs.lnk').tap { |path| path.write('shortcut') }
      store = Paperboy::FileStore.for(
        shortcut_path,
        env: { 'SMB_USERNAME' => 'user', 'SMB_PASSWORD' => 'password' },
        shortcut_class: NestedFakeShortcut,
        share_class: ->(**_options) { RecordingShare.new }
      )

      assert_equal Time.utc(2026, 9, 24, 10), store.mtime('finished.pdf')
    end
  end

  def test_shortcut_store_checks_nested_remote_directories
    Dir.mktmpdir do |directory|
      shortcut_path = Pathname.new(directory).join('outputs.lnk').tap { |path| path.write('shortcut') }
      store = Paperboy::FileStore.for(
        shortcut_path,
        env: { 'SMB_USERNAME' => 'user', 'SMB_PASSWORD' => 'password' },
        shortcut_class: NestedFakeShortcut,
        share_class: ->(**_options) { DirectoryListingShare.new }
      )

      assert store.directory?('Printer One')
      refute store.directory?('Missing')
    end
  end

  class FakeShortcut
    def initialize(_path); end

    def target
      '\\\\server\\share\\Shipping'
    end

    def host
      'server'
    end

    def share
      'share'
    end
  end

  class RecordingShare
    attr_reader :calls

    def initialize
      @calls = []
    end

    def put(source, target)
      calls << [:put, source, target]
    end

    def entries(_path = nil)
      timestamp = Time.utc(2026, 9, 24, 10)
      [
        { name: 'Printer One', directory: true, modified_at: timestamp },
        { name: 'finished.pdf', directory: false, modified_at: timestamp }
      ]
    end
  end

  class NestedFakeShortcut < FakeShortcut
    def folder
      'Printers'
    end
  end

  class DirectoryShare < RecordingShare
    def list(path)
      calls << [:list, path]
      raise SmbShortcut::CommandError, 'missing directory'
    end

    def mkdir(path)
      calls << [:mkdir, path]
    end
  end

  class DirectoryListingShare < RecordingShare
    def list(path)
      raise SmbShortcut::CommandError, 'missing directory' if path.end_with?('Missing')

      ['finished.pdf']
    end
  end
end
