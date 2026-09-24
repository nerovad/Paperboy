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
end
