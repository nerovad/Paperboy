# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
require_relative '../../app/services/workflow_outputs'

class WorkflowOutputsServiceTest < ActiveSupport::TestCase
  Entry = Data.define(:slug, :output_name)

  test 'lists and finds files from a shortcut-backed output root' do
    store = RemoteStore.new
    entry = Entry.new(slug: 'employees', output_name: 'employees.csv')

    Paperboy::FileStore.stub(:for, store) do
      outputs = WorkflowOutputs.new(entry, root: Pathname('/data/output.lnk'))
      files = outputs.files

      assert_equal ['02_Normalized/employees.csv'], files.map(&:relative_path)
      found = outputs.find!('02_Normalized/employees.csv')
      assert_equal files.first.relative_path, found.relative_path
      assert_equal files.first.mtime, found.mtime
      assert_equal 'employees.csv', files.first.basename.to_s
    end
  end

  test 'cleans up a materialized remote output file' do
    store = RemoteStore.new
    entry = Entry.new(slug: 'employees', output_name: 'employees.csv')

    Paperboy::FileStore.stub(:for, store) do
      file = WorkflowOutputs.new(entry, root: Pathname('/data/output.lnk'))
                            .find!('02_Normalized/employees.csv')
      path = file.local_path

      assert_path_exists path
      file.cleanup
      assert_equal [path], store.cleaned_paths
    end
  end

  class RemoteStore
    attr_reader :cleaned_paths

    def initialize
      @cleaned_paths = []
    end

    def walk(prefix = nil)
      entries = {
        nil => [{ name: '02_Normalized/employees.csv', modified_at: Time.utc(2026, 9, 24) },
                { name: '02_Normalized/other.csv', modified_at: Time.utc(2026, 9, 24) }],
        '06_Download_Backup' => []
      }
      entries.fetch(prefix)
    end

    def download(_name)
      path = Pathname(Dir.mktmpdir('workflow-output-test')).join('output')
      path.write('output')
      path
    end

    def cleanup_download(path)
      @cleaned_paths << path
    end
  end
end
