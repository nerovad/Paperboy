# frozen_string_literal: true

require 'test_helper'
require_relative '../support/step_task_scenario'

# A routing step with several routes: the submission's status stays the step
# while each route's task is checked off on its own, and the form moves once
# the step's completion rule is met.
class TrackableStatusStepTasksTest < ActiveSupport::TestCase
  include StepTaskScenario

  test 'arriving on the step opens one task per route and names nobody on the form' do
    start

    assert_equal 'step_1_pending', @form.status
    assert_nil @form.approver_id
    assert_equal ['Pending Manager Approval', 'Waiting on Vendor Approval', 'Waiting on Quote'],
                 @form.current_step_tasks.map(&:label)
    assert_equal [MANAGER, VENDOR, nil], @form.current_step_tasks.map(&:assignee_id)
  end

  test 'everyone with an open task is an approver at the step' do
    start

    routed { assert_equal [MANAGER, VENDOR, ACCOUNTANT], @step.eligible_approver_ids(@form) }
  end

  test 'one approval closes that task and leaves the form at the step' do
    start
    approve(VENDOR)

    assert_equal 'step_1_pending', @form.status
    assert_equal %w[pending approved pending], states
    routed { assert_equal [MANAGER, ACCOUNTANT], @step.eligible_approver_ids(@form) }
  end

  test 'the form moves on once every route has approved' do
    start
    [MANAGER, VENDOR, ACCOUNTANT].each { |employee_id| approve(employee_id) }

    assert_predicate @form, :approved?
    assert_equal %w[approved approved approved], states
  end

  test 'it moves to the next step when there is one' do
    @template.routing_steps.create!(step_number: 2, routing_type: 'employee', employee_id: 600)
    start
    [MANAGER, VENDOR, ACCOUNTANT].each { |employee_id| approve(employee_id) }

    assert_equal 'step_2_pending', @form.status
    assert_equal '600', @form.approver_id
  end

  test 'approving twice, or without a task, changes nothing' do
    start
    approve(VENDOR)

    assert_no_difference -> { @form.status_changes.count } do
      approve(VENDOR)
      approve(SUBMITTER)
    end
    assert_equal %w[pending approved pending], states
  end

  test 'each answer is written to the status history under its own label' do
    start
    approve(VENDOR)

    change = @form.status_changes.order(:id).last

    assert_equal 'Waiting on Vendor Approval', change.from_status
    assert_equal 'Waiting on Vendor Approval: Approved', change.to_status
    assert_equal VENDOR, change.changed_by_id
  end

  test 'whoever answered keeps a tracking copy' do
    start
    approve(VENDOR)

    assert Forms::SubmissionCopy.active.exists?(submission_type: 'IdBadgeRequestForm', submission_id: @form.id,
                                                recipient_employee_id: VENDOR.to_i)
  end

  test 'under the any rule the first approval finishes the step' do
    @step.update!(completion_rule: 'any')
    start
    approve(ACCOUNTANT)

    assert_predicate @form, :approved?
    assert_equal %w[cancelled cancelled approved], states
  end

  test 'a route nobody can pick up is reported as stuck' do
    @form.update_columns(status: 'step_1_pending')
    @form.send(:open_step_tasks, @step)

    EmployeeGroup.stub(:member_ids, []) { assert @step.unstaffed?(@form) }
    routed { assert_not @step.unstaffed?(@form) }
  end

  test 'a single-route step opens no tasks and advances as it always has' do
    @step.routes.destroy_all
    @step.update!(routing_type: 'employee', employee_id: MANAGER.to_i)
    @form.start_approval!

    assert_equal MANAGER, @form.approver_id
    assert_empty @form.step_tasks

    approve(MANAGER)

    assert_predicate @form, :approved?
  end
end
