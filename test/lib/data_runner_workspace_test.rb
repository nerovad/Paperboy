# frozen_string_literal: true

require 'test_helper'
require Rails.root.join('script/ruby/data_runner/helpers/workspace')

class DataRunnerWorkspaceTest < ActiveSupport::TestCase
  test 'materializes remote stages and publishes successful outputs' do
    store = RemoteStore.new
    workspace = DataRunnerWorkspace.new(root: Pathname('/data/output.lnk'))

    Paperboy::FileStore.stub(:for, store) do
      result = workspace.run('EXAMPLE' => '1') do |environment|
        assert_path_exists environment.fetch('DATARUNNER_OUTPUT_ROOT')
        local_root = Pathname(environment.fetch('DATARUNNER_OUTPUT_ROOT'))
        assert_equal 'input', local_root.join('02_Normalized/input.csv').read
        local_root.join('02_Normalized/output.csv').write('output')
        true
      end

      assert result
    end

    assert_includes store.copies.map(&:last), '02_Normalized/output.csv'
  end

  test 'does not publish failed child stages' do
    store = RemoteStore.new
    workspace = DataRunnerWorkspace.new(root: Pathname('/data/output.lnk'))

    Paperboy::FileStore.stub(:for, store) do
      workspace.run do |environment|
        Pathname(environment.fetch('DATARUNNER_OUTPUT_ROOT')).join('02_Normalized/output.csv').write('output')
        false
      end
    end

    assert_empty store.copies
  end

  class RemoteStore
    attr_reader :copies

    def initialize
      @copies = []
      @source = Pathname(Dir.mktmpdir('paperboy-workspace-test')).join('input.csv')
      @source.write('input')
    end

    def walk(stage)
      stage == '02_Normalized' ? [{ name: '02_Normalized/input.csv' }] : []
    end

    def with_download(_name)
      yield @source
    end

    def copy(source, name)
      @copies << [source, name]
    end
  end
end
