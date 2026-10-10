# frozen_string_literal: true

require 'test_helper'

class EnvironmentAccessControllerTest < ActionController::TestCase
  test 'the landing page names the server and both ways on' do
    sign_in

    EnvironmentAccess.stub(:key_for, 'stage') { get :show }

    assert_response :success
    assert_select 'h1', text: 'This is the Stage server'
    assert_select '.environment-access p', text: /Development and Stage are for testing/
    assert_select 'a.btn.approve[href=?]', 'https://gsa-forms', text: 'Go to Production'
    assert_select 'a.btn[href=?]', EnvironmentAccess::SUPPORT_CHANNEL_URL, text: 'Ask in Paperboy-Support'
    assert_select 'form[action=?] button', logout_path, text: 'Sign out'
  end

  test 'somebody who may use this server is sent home rather than shown it' do
    sign_in(group_names: Set['system_admins'])

    EnvironmentAccess.stub(:key_for, 'stage') { get :show }

    assert_redirected_to root_path
  end

  test 'there is nothing to show where no grant is asked for' do
    sign_in

    get :show

    assert_redirected_to root_path
  end

  private

  def sign_in(group_names: Set.new)
    session[:user] = { 'employee_id' => 1, 'email' => 'tester@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
    @controller.define_singleton_method(:current_user_group_names) { group_names }
    @controller.define_singleton_method(:current_user_group_ids) { [] }
    @controller.define_singleton_method(:current_user_org_chain) { {} }
    @controller.define_singleton_method(:inbox_count) { 0 }
  end
end
