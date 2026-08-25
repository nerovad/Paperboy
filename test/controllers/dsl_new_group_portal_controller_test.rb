# frozen_string_literal: true

require 'test_helper'

class DslNewGroupPortalControllerTest < ActionController::TestCase
  tests DataRunner::DslsController

  test 'new group name opens an editable drop portal before it has members' do
    sign_in

    get :index, params: { group: 'Finance Reporting' }

    assert_response :success
    assert_select 'h1', text: 'Finance Reporting'
    assert_select 'form[data-controller=?][action=?]', 'dsl-group',
                  data_runner_dsl_group_path('finance_reporting')
    assert_select '.dsl-dropzone[data-dsl-group-target=?]', 'dropzone'
    assert_select '.empty-palette:not([hidden])', text: /Drag DSLs from the sidebar/
    assert_select '.data-runner-sidebar .nav-link[data-action*=?]',
                  'mousedown->dsl-drag#mousedown', minimum: 1
  end

  private

  def sign_in
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
  end
end
