# frozen_string_literal: true

require 'test_helper'
require_relative '../support/step_task_scenario'

# What a deny means at a routing step with several routes, under each of the
# step's two deny rules.
class TrackableStatusStepTaskDenialTest < ActiveSupport::TestCase
  include StepTaskScenario

  test 'by default one deny denies the form and closes the rest' do
    start
    Current.deny_reason = 'No budget'
    deny(MANAGER)

    assert_predicate @form, :denied?
    assert_equal %w[denied cancelled cancelled], states
    assert_equal 'No budget', @form.step_tasks.ordered.first.notes
  end

  test 'under the task deny rule a deny is recorded and the others still answer' do
    @step.update!(deny_rule: 'task')
    start
    deny(MANAGER)

    assert_equal 'step_1_pending', @form.status
    assert_equal %w[denied pending pending], states
  end

  test 'under the task deny rule the form is denied once everyone has answered' do
    @step.update!(deny_rule: 'task')
    start
    deny(MANAGER)
    approve(VENDOR)
    approve(ACCOUNTANT)

    assert_predicate @form, :denied?
    assert_equal %w[denied approved approved], states
  end

  test 'under the task deny rule someone with no task cannot deny the form' do
    @step.update!(deny_rule: 'task')
    start
    deny(SUBMITTER)

    assert_equal 'step_1_pending', @form.status
    assert_equal %w[pending pending pending], states
  end

  test 'any approval outweighs a deny when the step needs only one' do
    @step.update!(completion_rule: 'any', deny_rule: 'task')
    start
    deny(MANAGER)
    approve(VENDOR)

    assert_predicate @form, :approved?
    assert_equal %w[denied approved cancelled], states
  end
end
