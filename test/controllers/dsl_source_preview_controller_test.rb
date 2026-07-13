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
