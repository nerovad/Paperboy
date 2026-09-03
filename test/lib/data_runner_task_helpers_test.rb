# frozen_string_literal: true

require 'test_helper'
require Rails.root.join('script/ruby/data_runner/helpers/task_helpers').to_s

class DataRunnerTaskHelpersTest < ActiveSupport::TestCase
  test 'optional task argument selects all when omitted' do
    args = { name: nil }

    assert_nil DataRunnerTaskHelpers.task_arg(args, [], allow_all: true, required: false)
  end

  test 'optional task argument still accepts a source name' do
    args = { name: 'widgets' }

    assert_equal 'widgets', DataRunnerTaskHelpers.task_arg(args, [], allow_all: true, required: false)
  end

  test 'all task argument selects all sources' do
    args = { name: 'ALL' }

    assert_nil DataRunnerTaskHelpers.task_arg(args, [], allow_all: true, required: false)
  end
end
