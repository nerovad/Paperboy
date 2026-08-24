# frozen_string_literal: true

require 'test_helper'
require Rails.root.join('script/ruby/data_runner/helpers/task_helpers')

class DataRunnerOrchestrationHelpersTest < ActiveSupport::TestCase
  CHILDREN = %w[One Two Three].map { |name| [name, {}] }.freeze

  test 'runs children in parallel and waits for all of them' do
    started = Queue.new
    release = Queue.new
    runner = nil

    DataRunnerTaskHelpers.stub(:orchestration_children, CHILDREN) do
      run_child = lambda do |_script, child|
        started << child
        release.pop
      end

      DataRunnerTaskHelpers.stub(:run_orchestrated_child, run_child) do
        runner = Thread.new { DataRunnerTaskHelpers.send(:run_children, {}, :inject) }
        assert_equal CHILDREN.map(&:first).sort, Array.new(CHILDREN.length) { started.pop }.sort
        CHILDREN.length.times { release << true }
        runner.join
      end
    end
  ensure
    CHILDREN.length.times { release << true }
    runner&.join
  end

  test 'reports every child failure after the stage finishes' do
    run_child = lambda do |_script, child|
      raise "#{child} failed" unless child == 'Two'
    end

    error = DataRunnerTaskHelpers.stub(:orchestration_children, CHILDREN) do
      DataRunnerTaskHelpers.stub(:run_orchestrated_child, run_child) do
        assert_raises(RuntimeError) { DataRunnerTaskHelpers.send(:run_children, {}, :inject) }
      end
    end

    assert_match 'One: One failed', error.message
    assert_match 'Three: Three failed', error.message
  end

  test 'runs atomic injection for all children in one process' do
    calls = []
    runner = lambda do |script, *children, **options|
      calls << [script, children, options]
    end

    DataRunnerTaskHelpers.stub(:orchestration_children, CHILDREN) do
      DataRunnerTaskHelpers.stub(:run_ruby_stage, runner) do
        DataRunnerTaskHelpers.send(:run_atomic_inject, {})
      end
    end

    script, children, options = calls.fetch(0)
    assert_equal 'inject.rb', script
    assert_equal CHILDREN.map(&:first), children
    assert_equal '1', options.fetch(:environment).fetch('DATARUNNER_ATOMIC_INJECT')
  end
end
