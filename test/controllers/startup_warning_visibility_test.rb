# frozen_string_literal: true

require 'test_helper'

# The layout hands StartupConfiguration's warnings to the startup-warning
# Stimulus controller, which opens a dialog on the first page of a session.
# The warnings name hosts, paths and databases, and only a system admin can do
# anything about them, so the element renders for nobody else.
class StartupWarningVisibilityTest < ActionController::TestCase
  tests FormsController

  WARNING = { key: 'GSABSS_HOST', value: '(undefined)', error: 'is not defined.' }.freeze

  setup do
    session[:user] = { 'employee_id' => '9999', 'email' => 'viewer@example.com',
                       'first_name' => 'Dana', 'last_name' => 'Reyes' }
    @controller.define_singleton_method(:inbox_count) { 0 }
  end

  test 'a system admin is sent the startup warnings' do
    @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }

    with_warnings { get :home }

    assert_response :success
    assert_select '[data-controller=?]', 'startup-warning', count: 1
    assert_match 'GSABSS_HOST', response.body
  end

  test 'anyone else is not' do
    @controller.define_singleton_method(:current_user_group_names) { Set['editors'] }

    with_warnings { get :home }

    assert_response :success
    assert_select '[data-controller=?]', 'startup-warning', count: 0
    assert_no_match 'GSABSS_HOST', response.body
  end

  test 'a signed-out visitor is not' do
    session.delete(:user)

    with_warnings { get :home }

    assert_response :success
    assert_select '[data-controller=?]', 'startup-warning', count: 0
  end

  private

  def with_warnings(&block)
    StartupConfiguration.stub(:warnings, [WARNING], &block)
  end
end
