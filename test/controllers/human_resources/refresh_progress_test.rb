# frozen_string_literal: true

require 'test_helper'

class HumanResourcesRefreshProgressTest < ActionController::TestCase
  tests DataRunner::GroupRunsController

  test 'keeps Human Resources data refresh progress in Human Resources' do
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
    run = DataRunner::GroupRun.create!(run_id: SecureRandom.uuid,
                                       group_name: HumanResources::DataRefresh::GROUP_RUN_NAME,
                                       status: 'failed', total_count: 1, completed_count: 1, failed_count: 1)

    get :show, params: { id: run.id }

    assert_redirected_to human_resources_data_refresh_run_path(run)
  end
end
