# frozen_string_literal: true

require 'test_helper'

class DslActiveGroupRunControllerTest < ActionController::TestCase
  tests DataRunner::DslsController

  test 'run task is disabled for a DSL in an active group refresh' do
    sign_in
    create_active_run(status: 'running')

    get :show, params: { name: 'activities' }

    assert_response :success
    assert_select '.hot-menu button.btn.approve[disabled]', text: 'Run Task'
    assert_select '.hot-menu details', count: 0
  end

  test 'run endpoint rejects a DSL in an active group refresh' do
    sign_in
    create_active_run(status: 'queued')
    called = false

    TaskRunner.stub(:run!, ->(**) { called = true }) do
      post :run, params: { name: 'activities', task_name: 'inject' }
    end

    assert_redirected_to data_runner_dsl_path('activities')
    assert_equal 'Chart of accounts refresh is in progress. Run Task is disabled.', flash[:alert]
    assert_not called
  end

  test 'active group refresh does not disable unrelated DSLs' do
    sign_in
    create_active_run(status: 'running')

    get :show, params: { name: 'parking_lots' }

    assert_response :success
    assert_select '.hot-menu details summary.btn.approve', text: 'Run Task'
    assert_select '.hot-menu button[disabled]', text: 'Run Task', count: 0
  end

  private

  def create_active_run(status:)
    DataRunner::GroupRun.create!(run_id: SecureRandom.uuid, group_name: 'chart_of_accounts',
                                 status: status, total_count: 1)
  end

  def sign_in
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
  end
end
