# frozen_string_literal: true

require 'test_helper'

class DataRunnerGroupRunsControllerTest < ActionController::TestCase
  tests DataRunner::GroupRunsController

  test 'shows persisted group progress' do
    sign_in
    run = create_run

    get :show, params: { id: run.id }

    assert_response :success
    assert_select '[data-controller=?]', 'group-run'
    assert_select '[data-group-run-status=?]', 'running'
    assert_select 'li.group-run-item', count: 2
    assert_select 'p', text: /Processing will continue/
  end

  test 'returns refreshable progress markup' do
    sign_in
    run = create_run

    get :status, params: { id: run.id }

    assert_response :success
    assert_select '[data-group-run-status=?]', 'running'
    assert_select 'progress[max=?][value=?]', '2', '0'
  end

  private

  def create_run
    run = DataRunner::GroupRun.create!(run_id: SecureRandom.uuid, group_name: 'chart_of_accounts',
                                       status: 'running', total_count: 2)
    run.items.create!(dsl_name: 'Activities', dsl_slug: 'activities', position: 0)
    run.items.create!(dsl_name: 'Agencies', dsl_slug: 'agencies', position: 1)
    run
  end

  def sign_in
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
  end
end
