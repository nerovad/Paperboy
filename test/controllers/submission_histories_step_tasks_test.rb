# frozen_string_literal: true

require 'test_helper'
require_relative '../support/step_task_scenario'

# Status History shows the checklist of a routing step with several routes
# above the timeline, for as long as the submission stands at that step.
class SubmissionHistoriesStepTasksTest < ActionController::TestCase
  include StepTaskScenario

  tests SubmissionHistoriesController

  setup do
    session[:user] = { 'employee_id' => StepTaskScenario::VENDOR, 'email' => 'greg@example.com',
                       'first_name' => 'Greg', 'last_name' => 'Bergman' }
    @controller.define_singleton_method(:inbox_count) { 0 }
    @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
  end

  test 'the checklist lists every route with its own state' do
    start
    approve(StepTaskScenario::VENDOR)

    routed { get :status, params: { type: 'IdBadgeRequestForm', id: @form.id } }

    assert_response :success
    assert_select '.step-tasks__header', text: /Waiting on 2 of 3/
    assert_select '.step-tasks__item', count: 3
    assert_select '.step-tasks__item .badge.is-approved', text: 'Approved', count: 1
    assert_select '.step-tasks__label', text: 'Waiting on Quote'
  end

  test 'a submission with no checklist shows only its timeline' do
    get :status, params: { type: 'IdBadgeRequestForm', id: @form.id }

    assert_response :success
    assert_select '.step-tasks', count: 0
  end
end
