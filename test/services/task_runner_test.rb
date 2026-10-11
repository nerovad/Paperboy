# frozen_string_literal: true

require 'test_helper'

class TaskRunnerTest < ActiveSupport::TestCase
  test 'rejects arbitrary task names before execution' do
    error = assert_raises(ArgumentError) { TaskRunner.run!(task: 'db:drop', selector: 'employees') }

    assert_equal 'Task is not allowed', error.message
  end

  test 'rejects invalid run ids' do
    assert_raises(ActiveRecord::RecordNotFound) { TaskRunner.output!('../../etc/passwd') }
  end

  test 'resolves dsl slugs and group names for rake selectors' do
    assert_equal 'Employees', TaskRunner.selector_name!('employees')
    assert_equal 'chart_of_accounts', TaskRunner.selector_name!('chart_of_accounts')
    assert_raises(ActiveRecord::RecordNotFound) { TaskRunner.selector_name!('missing_selector') }
  end

  test 'resolves multiple dsl selectors' do
    assert_equal %w[Employees ParkingLots], TaskRunner.selector_names!(%w[employees parking_lots])
  end

  test 'starts a selector in its own process group and reports the pid' do
    received = nil
    seen_pid = nil
    status = Struct.new(:success?).new(true)
    thread = Struct.new(:pid, :value).new(321, status)
    popen = lambda do |*args, **kwargs, &block|
      received = { args: args, kwargs: kwargs }
      block.call(StringIO.new, StringIO.new, thread)
    end

    Open3.stub(:popen2e, popen) do
      result = TaskRunner.run_selector!(task: 'refresh', selector: 'employees', output: StringIO.new,
                                        on_start: ->(pid) { seen_pid = pid })

      assert_equal status, result
    end

    assert_equal true, received[:kwargs][:pgroup]
    assert_equal Rails.root.to_s, received[:kwargs][:chdir]
    assert_includes received[:args], 'DataRunner:refresh'
    assert_includes received[:args], 'Employees'
    assert_equal 321, seen_pid
  end

  test 'exposes a stable path for streamed run output' do
    id = '00000000-0000-0000-0000-000000000000'

    assert_equal Rails.root.join('tmp/web_runs', "#{id}.log"), TaskRunner.output_path(id)
  end
end
