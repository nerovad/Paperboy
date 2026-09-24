# frozen_string_literal: true

require 'test_helper'
require Rails.root.join('script/ruby/data_runner/helpers/download_store')

class DataRunnerDownloadStoreTest < ActiveSupport::TestCase
  test 'copies and backs up files through local stage stores' do
    Dir.mktmpdir do |directory|
      root = Pathname.new(directory)
      source = root.join('source.csv').tap { |path| path.write('source') }
      store = DataRunnerDownloadStore.new(root: root)
      store.prepare!
      store.copy_source(source, 'data.csv')

      assert store.target_exists?('data.csv')
      backup = store.backup_existing('data.csv')

      assert_match(/\A\d{4}-\d{2}-\d{2}-\d{3}-data\.csv\z/, backup)
      assert root.join(WorkflowPaths::DOWNLOAD_BACKUP_DIR_NAME, backup).file?
    end
  end

  test 'publishes a shortcut-backed workspace file' do
    remote = RemoteStore.new
    store = Paperboy::FileStore.stub(:for, remote) do
      DataRunnerDownloadStore.new(root: Pathname('/data/output.lnk'))
    end

    store.with_workspace do |workspace|
      workspace.join(WorkflowPaths::DOWNLOAD_DIR_NAME, 'data.csv').write('output')
      assert store.publish_workspace_file(workspace, 'data.csv')
    end

    assert_equal ['01_Download/data.csv'], remote.copies.map(&:last)
  end

  test 'removes a shortcut-backed workspace after a failure' do
    remote = RemoteStore.new
    store = Paperboy::FileStore.stub(:for, remote) do
      DataRunnerDownloadStore.new(root: Pathname('/data/output.lnk'))
    end
    workspace = nil

    assert_raises(RuntimeError) do
      store.with_workspace do |path|
        workspace = path
        raise 'child failed'
      end
    end

    refute_path_exists workspace
  end

  class RemoteStore
    attr_reader :copies

    def initialize
      @copies = []
    end

    def mkdir(_prefix); end

    def copy(source, name)
      @copies << [source, name]
    end

    def entries(_prefix = nil)
      []
    end
  end
end
