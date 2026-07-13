# frozen_string_literal: true

require 'test_helper'

class AuthenticationTest < ActionDispatch::IntegrationTest
  test 'landing page offers employee single sign on' do
    get data_runner_root_path

    assert_response :success
    assert_select 'form[action=?]', auth_setup_path
    assert_select 'button[type=submit]', text: 'Employee sign in'
  end

  test 'protected DSL pages redirect to landing page' do
    get data_runner_dsl_path('employees')

    assert_redirected_to data_runner_root_path
  end
end
