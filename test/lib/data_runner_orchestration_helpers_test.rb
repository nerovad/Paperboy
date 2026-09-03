# frozen_string_literal: true

require 'test_helper'
require Rails.root.join('script/ruby/data_runner/helpers/task_helpers')
require 'tmpdir'

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

  test 'rejects a queued OMS number that already has an archive' do
    Dir.mktmpdir do |directory|
      FileUtils.mkdir_p(File.join(directory, '02_Processed/50506986'))
      orchestration = { root_path: directory, processed_path: '02_Processed' }

      error = assert_raises(RuntimeError) do
        DataRunnerTaskHelpers.send(
          :ensure_queue_entry_not_processed!, orchestration, 'Mail.dat_50506986.zip'
        )
      end

      assert_match 'duplicate OMS number', error.message
    end
  end
end
