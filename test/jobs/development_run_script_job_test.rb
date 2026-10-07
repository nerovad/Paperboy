# frozen_string_literal: true

require 'test_helper'

class DevelopmentRunScriptJobTest < ActiveJob::TestCase
  test 'runs the catalog program with the validated arguments' do
    run = queued_run
    status = Struct.new(:success?, :exitstatus).new(true, 0)
    captured = nil
    program = Rails.root.join('bin', 'status-report').to_s

    Open3.stub(:capture2e, lambda { |*argv, **options|
      captured = [argv, options]
      ["ok\n", status]
    }) do
      Development::RunScriptJob.perform_now(run.id, 'status_report', ['--stale-days', '30'])
    end

    assert_equal [[program, program], '--stale-days', '30'], captured[0]
    assert_equal Rails.root.to_s, captured[1][:chdir]
    assert_equal 'succeeded', run.reload.status
  end

  test 'fails a run whose stored command differs' do
    run = queued_run
    run.update_columns(command_json: ['/bin/sh', '-c', 'id'].to_json)
    captured = nil

    assert_raises(ArgumentError) do
      Open3.stub(:capture2e, ->(*argv, **options) { captured = [argv, options] }) do
        Development::RunScriptJob.perform_now(run.id, 'status_report', ['--stale-days', '30'])
      end
    end

    assert_nil captured
    assert_equal 'failed', run.reload.status
  end

  test 'fails a run whose script is not in the catalog' do
    run = queued_run
    captured = nil

    assert_raises(ArgumentError) do
      Open3.stub(:capture2e, ->(*argv, **options) { captured = [argv, options] }) do
        Development::RunScriptJob.perform_now(run.id, 'not_a_script', [])
      end
    end

    assert_nil captured
    assert_equal 'failed', run.reload.status
  end

  private

  def queued_run
    Development::Run.create!(
      script_key: 'status_report',
      script_label: 'Gitea Status Report',
      requested_by: 'dev@example.com',
      status: 'queued',
      command: Development::CommandBuilder.new(
        Development::ScriptCatalog.find('status_report'),
        ['--stale-days', '30']
      ).to_a
    )
  end
end
