# frozen_string_literal: true

require 'test_helper'
require Rails.root.join('script/ruby/data_runner/constants/workflow_paths').to_s

class DataRunnerWorkflowPathsTest < ActiveSupport::TestCase
  test 'inbox path points to the shared DataRunner inbox' do
    expected = ENV.fetch('DATARUNNER_INBOX')

    assert_equal expected, WorkflowPaths::INBOX_DIR
  end
end
