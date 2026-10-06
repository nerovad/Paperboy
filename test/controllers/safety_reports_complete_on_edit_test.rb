# frozen_string_literal: true

require 'test_helper'

# Forms::BaseController completes a "saving the form completes this step"
# routing step after a successful update. Safety Reporting is the form it was
# built for: the safety officer's save should take the report out of their
# inbox rather than leave it waiting for an Approve.
class SafetyReportsCompleteOnEditTest < ActionController::TestCase
  tests Forms::SafetyReportsController

  OFFICER = '500'

  setup do
    session[:user] = { 'employee_id' => OFFICER, 'email' => 'officer@example.com' }
    @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    @controller.define_singleton_method(:inbox_count) { 0 }

    template = Forms::Template.create!(name: 'Safety Reporting', class_name: 'SafetyReport',
                                       page_count: 2, submission_type: 'database')
    @step = template.routing_steps.create!(step_number: 1, routing_type: 'authorization',
                                           authorization_service_type: 'hca_safety', complete_on_edit: true)
    @report = SafetyReport.create!(name: 'Pat Example', email: 'pat@example.com', employee_id: '900')
    @report.update_columns(status: 'step_1_pending')
  end

  def save_as_officer(attributes)
    AuthorizationConsole.stub(:approver_ids_for, [OFFICER]) do
      patch :update, params: { id: @report.id, safety_report: attributes }
    end
  end

  test 'the officer saving the form puts it in its end state' do
    save_as_officer(name: 'Pat Example-Smith')

    assert_response :see_other
    assert_equal 'Pat Example-Smith', @report.reload.name
    assert_predicate @report, :approved?
    assert_predicate @report, :terminal?
  end

  test 'a save that fails validation leaves the step open' do
    save_as_officer(name: '')

    assert_response :unprocessable_entity
    assert_equal 'step_1_pending', @report.reload.status
  end

  test 'a step without the option still waits for Approve' do
    @step.update!(complete_on_edit: false)
    save_as_officer(name: 'Pat Example-Smith')

    assert_response :see_other
    assert_equal 'step_1_pending', @report.reload.status
  end
end
