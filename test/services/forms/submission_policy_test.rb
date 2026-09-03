# frozen_string_literal: true

require 'test_helper'

module Forms
  class SubmissionPolicyTest < ActiveSupport::TestCase
    # A dynamic form sitting at a pool step: approver_id stays nil so the whole
    # queue can act on it, which is exactly the case the assignment columns
    # can't see.
    FakeSubmission = Struct.new(:employee_id, :approver_id, :status)

    # Stands in for a Forms::TemplateRoutingStep. Only the eligibility question
    # matters here, and passing the step in keeps the policy off the database.
    FakeStep = Struct.new(:approver_ids) do
      def eligible_approver_ids(_submission)
        approver_ids
      end
    end

    def pool_submission
      FakeSubmission.new('900', nil, 'step_1_pending')
    end

    def permitted?(record, action, employee_id, step)
      Forms::SubmissionPolicy.permitted?(
        record, action: action, employee_id: employee_id, routing_step: step
      )
    end

    test 'an approver at a pool step may edit even though approver_id is nil' do
      step = FakeStep.new(%w[500 501])

      assert permitted?(pool_submission, 'edit', '500', step)
    end

    test 'a pool step approver may also change the status' do
      step = FakeStep.new(%w[500])

      assert permitted?(pool_submission, 'change_status', '500', step)
    end

    test 'someone outside the pool is still refused' do
      step = FakeStep.new(%w[500 501])

      assert_not permitted?(pool_submission, 'edit', '777', step)
    end

    test 'the submitter keeps edit and is still refused change_status' do
      step = FakeStep.new(%w[500])

      assert permitted?(pool_submission, 'edit', '900', step)
      assert_not permitted?(pool_submission, 'change_status', '900', step)
    end

    test 'a step routing to nobody grants nothing' do
      assert_not permitted?(pool_submission, 'edit', '500', FakeStep.new([]))
    end

    test 'a submission past its routing steps has no step to ask' do
      approved = FakeSubmission.new('900', nil, 'approved')

      assert_not permitted?(approved, 'change_status', '500', nil)
    end

    test 'the stamped approver is still permitted' do
      stamped = FakeSubmission.new('900', '500', 'approved')

      assert permitted?(stamped, 'edit', '500', nil)
      assert permitted?(stamped, 'change_status', '500', nil)
    end
  end
end
