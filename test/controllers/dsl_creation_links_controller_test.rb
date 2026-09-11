# frozen_string_literal: true

require 'test_helper'

class DslCreationLinksControllerTest < ActionController::TestCase
  tests DataRunner::DslsController

  test 'sidebar offers descriptive inbox and database DSL actions' do
    sign_in

    get :index

    assert_response :success
    assert_select 'form[action=?] input.btn.secondary', data_runner_inbox_dsls_path,
                  value: 'Discover Inbox Files'
    assert_select 'a.btn.secondary[href=?]', new_data_runner_database_dsls_path,
                  text: 'Import Database Table'
  end

  private

  def sign_in
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
    @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    @controller.define_singleton_method(:system_admin?) { true }
    @controller.define_singleton_method(:current_user_feature_permission_keys) do
      Set[AppFeature.permission_key('data_runner', 'manage_groups')]
    end
  end
end
