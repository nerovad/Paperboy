# frozen_string_literal: true

require 'test_helper'
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
      assert_equal files.first, outputs.find!('02_Normalized/employees.csv')
      assert_equal 'employees.csv', files.first.basename.to_s
    end
  end

  class RemoteStore
    def walk(prefix = nil)
      entries = {
        nil => [{ name: '02_Normalized/employees.csv', modified_at: Time.utc(2026, 9, 24) },
                { name: '02_Normalized/other.csv', modified_at: Time.utc(2026, 9, 24) }],
        '06_Download_Backup' => []
      }
      entries.fetch(prefix)
    end
  end
end
