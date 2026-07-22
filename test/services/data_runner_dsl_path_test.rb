# frozen_string_literal: true

require 'test_helper'
require 'open3'

class DataRunnerDslPathTest < ActiveSupport::TestCase
  test 'DSL map loads entries from the repository DSL directory' do
    script = Rails.root.join('script/ruby/data_runner/commands/dsl_map.rb')
    command = "require #{script.to_s.inspect}; print DSL_MAP.key?('Units')"

    output, status = Open3.capture2e(RbConfig.ruby, '-e', command)

    assert status.success?, output
    assert_equal 'true', output
  end
end
