# frozen_string_literal: true

require 'test_helper'

class DslSourcePreviewControllerTest < ActionController::TestCase
  tests DataRunner::DslsController

  test 'overview renders the full DSL source preview' do
    sign_in

    get :show, params: { name: 'employees' }

    assert_response :success
    assert_select 'pre.highlighted-output', text: /mode: :truncate_insert/
  end

  test 'task output replaces the DSL source preview' do
    sign_in
    run_id = '00000000-0000-0000-0000-000000000001'
    output_path = Rails.root.join('tmp/web_runs', "#{run_id}.log")
    output_path.dirname.mkpath
    output_path.write("Download completed.\n")

    get :show, params: {
      name: 'employees', run_id: run_id, task_status: 'succeeded', task_name: 'download'
    }

    assert_response :success
    assert_select '.task-result', text: /Download completed\./
    assert_select 'pre.output', false
    assert_select 'pre.task-output-box', count: 1
    assert_select '.task-result-actions a.btn.compact[href=?]', data_runner_dsl_path('employees'), text: 'Close'
  ensure
    output_path&.delete if output_path&.file?
  end

  private

  def sign_in
    session[:user] = {
      'employee_id' => 1,
      'email' => 'employee@example.com',
      'first_name' => 'Test',
      'last_name' => 'User'
    }
  end
end
