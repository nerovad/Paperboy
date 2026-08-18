# frozen_string_literal: true

require 'test_helper'
require Rails.root.join('script/ruby/data_runner/helpers/dependency_helpers')

class DataRunnerDependencyHelpersTest < ActiveSupport::TestCase
  FakeResult = Struct.new(:rows) do
    include Enumerable

    def each(&block) = rows.each(&block)
  end

  FakeClient = Struct.new(:rows) do
    def escape(value) = value
    def execute(_sql) = FakeResult.new(rows)
  end

  test 'satisfies a dependency only after its injection succeeds' do
    client = FakeClient.new([{ 'script' => 'script/ruby/data_runner/commands/inject.rb',
                               'status' => 'succeeded' }])

    output = capture_io do
      DataRunnerDependencyHelpers.wait_for_log!(client, 'ZyzzyvaUnits', 'Units', SecureRandom.uuid)
    end.first

    assert_includes output, 'dependency Units injection succeeded'
  end

  test 'rejects a dependency whose latest stage failed' do
    client = FakeClient.new([{ script: 'script/ruby/data_runner/commands/download.rb', status: 'failed' }])

    error = assert_raises(RuntimeError) do
      DataRunnerDependencyHelpers.wait_for_log!(client, 'ZyzzyvaUnits', 'Units', SecureRandom.uuid)
    end

    assert_equal 'ZyzzyvaUnits: dependency Units failed', error.message
  end
end
