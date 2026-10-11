# frozen_string_literal: true

require 'test_helper'
require Rails.root.join('script/ruby/data_runner/constants/workflow')

class WorkflowTest < ActiveSupport::TestCase
  def config(manual_enabled: true, scheduled_enabled: true)
    {
      steps: {
        manual: { enabled: manual_enabled, steps: %i[download inject] },
        scheduled: { enabled: scheduled_enabled, frequency: :daily, steps: %i[download inject] }
      }
    }
  end

  test 'manual and scheduled execution are enabled independently' do
    assert_not Workflow.wants_step?(config(manual_enabled: false), :download)
    assert Workflow.wants_scheduled_step?(config(manual_enabled: false), :download, :daily)

    assert Workflow.wants_step?(config(scheduled_enabled: false), :download)
    assert_not Workflow.wants_scheduled_step?(config(scheduled_enabled: false), :download, :daily)
  end

  test 'orchestration bypasses manual enabled without bypassing the step list' do
    previous = ENV.fetch(Workflow::ORCHESTRATION_ENV, nil)
    ENV[Workflow::ORCHESTRATION_ENV] = '1'

    assert Workflow.wants_step?(config(manual_enabled: false), :download)
    assert_not Workflow.wants_step?(config(manual_enabled: false), :create_table)
  ensure
    ENV[Workflow::ORCHESTRATION_ENV] = previous
  end

  test 'replicate steps stream the extract and then inject' do
    assert_equal %i[replicate inject], Workflow::REPLICATE_STEPS
    assert_not_includes Workflow::ALL_STEPS, :replicate
    assert_equal %w[replicate.rb inject.rb], Workflow.refresh_scripts(Workflow::REPLICATE_STEPS)
    assert_equal %w[download.rb to_csv.rb use_dsl.rb inject.rb], Workflow.refresh_scripts(Workflow::SCHEDULED_STEPS)

    cfg = {
      steps: {
        manual: { enabled: true, steps: Workflow::REPLICATE_STEPS },
        scheduled: { enabled: false, frequency: :daily, steps: Workflow::REPLICATE_STEPS }
      }
    }

    assert Workflow.wants_step?(cfg, :replicate)
    assert Workflow.wants_step?(cfg, :inject)
    assert_not Workflow.wants_step?(cfg, :download)
    assert_not Workflow.wants_step?(cfg, :to_csv)
    assert_not Workflow.wants_step?(cfg, :use_dsl)
    assert_not Workflow.wants_scheduled_step?(cfg, :replicate, :daily)
    assert_not Workflow.wants_scheduled_step?(cfg, :inject, :daily)
  end

  test 'normalizes legacy workflow settings' do
    legacy = {
      steps: {
        enabled: false,
        manual_steps: Workflow::MANUAL_STEPS,
        scheduled: { frequency: :daily, steps: Workflow::SCHEDULED_STEPS }
      }
    }

    assert_not Workflow.wants_step?(legacy, :inject)
    assert_not Workflow.wants_scheduled_step?(legacy, :inject, :daily)
  end
end
