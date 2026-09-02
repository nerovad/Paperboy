# frozen_string_literal: true

require 'test_helper'

class AwayReassignmentTest < ActiveSupport::TestCase
  setup do
    @period = AwayPeriod.create!(employee_id: '7100', delegate_id: '7200',
                                 starts_on: Date.current, ends_on: 1.week.from_now.to_date)
  end

  def form(approver: '7100', status: 'step_1_pending')
    LeaveOfAbsenceForm.create!(name: 'Away Sweep', email: 'sweep@ventura.org',
                               approver_id: approver, status: status)
  end

  # reassign_to! checks the new assignee exists in GSABSS, which the suite does
  # not read; any truthy value gets past that guard.
  def sweep
    Employee.stub(:find_by, Object.new) { AwayReassignment.new(@period).call }
  end

  test 'open work assigned to the away employee moves to the delegate' do
    task = form

    result = sweep

    assert_equal '7200', task.reload.approver_id
    assert_equal 1, result.moved
  end

  test 'work belonging to somebody else is untouched' do
    other = form(approver: '7999')

    sweep

    assert_equal '7999', other.reload.approver_id
  end

  test 'finished work is left where it is' do
    done = form(status: 'approved')

    sweep

    assert_equal '7100', done.reload.approver_id
  end

  test 'the handover leaves a reassignment history row' do
    task = form

    assert_difference -> { TaskReassignment.where(task_type: 'LeaveOfAbsenceForm', task_id: task.id).count }, 1 do
      sweep
    end
  end

  test 'sweeping twice moves nothing the second time' do
    form
    sweep

    assert_equal 0, sweep.moved
  end

  test 'reassignable_models includes both hand-written and form-builder forms' do
    models = AwayReassignment.reassignable_models.map(&:name)

    assert_includes models, 'LeaveOfAbsenceForm'
    assert_includes models, 'CriticalInformationReporting'
    assert_includes models, 'ProbationTransferRequest'
  end
end
