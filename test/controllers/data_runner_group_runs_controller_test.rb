# frozen_string_literal: true

require 'test_helper'

class DataRunnerGroupRunsControllerTest < ActionController::TestCase
  tests DataRunner::GroupRunsController

  test 'shows persisted group progress' do
    sign_in
    run = create_run

    get :show, params: { id: run.id }

    assert_response :success
    assert_select '[data-controller=?]', 'progress-tracker'
    assert_select '[data-progress-status=?]', 'running'
    assert_select 'li.progress-tracker__item', count: 2
    assert_select '.progress-tracker__item-label', text: /Succeeded · 1.3s/
    assert_select 'form[action=?]', data_runner_refresh_dsl_group_path(run.group_name, restart: 1) do
      assert_select 'button.btn.warning', text: 'Restart interrupted refresh'
    end
    assert_select 'p', text: /Processing will continue/
  end

  test 'returns refreshable progress markup' do
    sign_in
    run = create_run

    get :status, params: { id: run.id }

    assert_response :success
    assert_select '[data-progress-status=?]', 'running'
    assert_select 'progress[max=?][value=?]', '2', '0'
  end

  test 'offers to restart a failed refresh' do
    sign_in
    run = DataRunner::GroupRun.create!(run_id: SecureRandom.uuid, group_name: 'chart_of_accounts',
                                       status: 'failed', total_count: 2, completed_count: 2,
                                       failed_count: 1, completed_at: Time.current)

    get :show, params: { id: run.id }

    assert_response :success
    assert_select 'form[action=?][method=?]', data_runner_refresh_dsl_group_path(run.group_name), 'post' do
      assert_select 'button.btn.approve[data-turbo-confirm=?]', 'Restart the Chart of accounts refresh?',
                    text: 'Restart refresh'
    end
  end

  test 'keeps Billing data refresh progress in Billing' do
    sign_in
    run = DataRunner::GroupRun.create!(run_id: SecureRandom.uuid,
                                       group_name: Billing::DataRefresh::GROUP_RUN_NAME,
                                       status: 'failed', total_count: 1, completed_count: 1, failed_count: 1)

    get :show, params: { id: run.id }

    assert_redirected_to billing_data_refresh_run_path(run)
  end

  private

  def create_run
    run = DataRunner::GroupRun.create!(run_id: SecureRandom.uuid, group_name: 'chart_of_accounts',
                                       status: 'running', total_count: 2)
    run.items.create!(dsl_name: 'Activities', dsl_slug: 'activities', position: 0)
    run.items.create!(dsl_name: 'Agencies', dsl_slug: 'agencies', position: 1,
                      status: 'succeeded', duration_ms: 1250)
    run
  end

  def sign_in
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
  end
end
