# frozen_string_literal: true

require 'test_helper'

# A routing step configured with "Saving the form completes this step": the
# approver's save is the sign-off, and nobody else's is. Exercised through
# SafetyReport, the form the option was built for -- the safety officer fills
# in the investigation pages and should not then have to approve their own work.
class TrackableStatusCompleteOnEditTest < ActiveSupport::TestCase
  SUBMITTER = '900'
  OFFICER = '500'

  setup do
    @template = Forms::Template.create!(name: 'Safety Reporting', class_name: 'SafetyReport',
                                        page_count: 2, submission_type: 'database')
    @step = @template.routing_steps.create!(step_number: 1, routing_type: 'authorization',
                                            authorization_service_type: 'hca_safety', complete_on_edit: true)
    @report = SafetyReport.create!(name: 'Pat Example', email: 'pat@example.com', employee_id: SUBMITTER)
    @report.update_columns(status: 'step_1_pending')
  end

  # Who the pool step routes to, without a SafetyReportAuthorization lookup.
  def with_officers(*ids, &block)
    AuthorizationConsole.stub(:approver_ids_for, ids, &block)
  end

  test 'the approver saving the form completes the step' do
    with_officers(OFFICER) do
      assert @report.complete_step_on_edit!(OFFICER)
    end

    assert_predicate @report.reload, :approved?
  end

  test 'completing the step records the status change' do
    with_officers(OFFICER) do
      assert_difference -> { @report.status_changes.count }, 1 do
        @report.complete_step_on_edit!(OFFICER)
      end
    end
  end

  test 'the submitter saving their own form leaves the step where it is' do
    with_officers(OFFICER) do
      assert_nil @report.complete_step_on_edit!(SUBMITTER)
    end

    assert_equal 'step_1_pending', @report.reload.status
  end

  test 'a step without the option is only completed by Approve' do
    @step.update!(complete_on_edit: false)

    with_officers(OFFICER) do
      assert_nil @report.complete_step_on_edit!(OFFICER)
    end

    assert_equal 'step_1_pending', @report.reload.status
  end

  test 'once the submission is assigned to one person, only they complete it' do
    @report.update_columns(approver_id: '501')

    with_officers(OFFICER, '501') do
      assert_nil @report.complete_step_on_edit!(OFFICER)
      assert @report.complete_step_on_edit!('501')
    end
  end

  test 'a submission past its steps has nothing to complete' do
    @report.update_columns(status: 'approved')

    with_officers(OFFICER) do
      assert_nil @report.complete_step_on_edit!(OFFICER)
    end
  end

  test 'a save by nobody in particular completes nothing' do
    with_officers(OFFICER) do
      assert_nil @report.complete_step_on_edit!(nil)
    end
  end
end
