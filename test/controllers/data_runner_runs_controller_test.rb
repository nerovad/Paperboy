# frozen_string_literal: true

require 'test_helper'

class DataRunnerRunsControllerTest < ActionController::TestCase
  tests DataRunner::RunsController

  test 'shows a contained group log with a close action' do
    sign_in
    run_id = SecureRandom.uuid
    group_run = DataRunner::GroupRun.create!(run_id: run_id, group_name: 'chart_of_accounts',
                                             status: 'succeeded', total_count: 1, completed_count: 1)
    output_path = Rails.root.join('tmp/web_runs', "#{run_id}.log")
    output_path.dirname.mkpath
    output_path.write("Refresh completed.\n")

    get :show, params: { id: run_id }

    assert_response :success
    assert_select 'pre.captured-output.run-output', text: /Refresh completed\./
    assert_select 'a.btn.compact[href=?]', data_runner_group_run_path(group_run), text: 'Close'
  ensure
    output_path&.delete if output_path&.file?
  end

  private

  def sign_in
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
  end
end
