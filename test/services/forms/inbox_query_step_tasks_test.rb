# frozen_string_literal: true

require 'test_helper'
require_relative '../../support/step_task_scenario'

# A submission at a routing step with several routes is in the inbox of
# whoever still owes one of its tasks.
class InboxQueryStepTasksTest < ActiveSupport::TestCase
  include StepTaskScenario

  test 'the inbox shows the form to whoever still owes a task' do
    start

    routed do
      assert_includes inbox_for(MANAGER, group_ids: []), @form
      assert_includes inbox_for(ACCOUNTANT, group_ids: [GROUP_ID]), @form
      assert_not_includes inbox_for(SUBMITTER, group_ids: []), @form
    end

    approve(MANAGER)
    Forms::SubmissionCopy.delete_all

    routed { assert_not_includes inbox_for(MANAGER, group_ids: []), @form }
  end

  # The inbox reads an approval template's forms; group membership comes from
  # GSABSS, so it is stubbed to the groups given.
  def inbox_for(employee_id, group_ids:)
    @template.update_columns(submission_type: 'approval')
    membership = Minitest::Mock.new
    membership.expect(:distinct, membership)
    membership.expect(:pluck, group_ids, [:GroupID])

    EmployeeGroup.stub(:where, membership) do
      Employee.stub(:where, Employee.none) do
        Forms::InboxQuery.new(scoped_employee_ids: [employee_id]).submissions
      end
    end
  end
end
