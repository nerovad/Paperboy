# frozen_string_literal: true

require 'test_helper'

# Every DSL is an ACL > Application Features grant under Data Runner. The
# sidebar only hides, so what matters here is the gate behind it: a DSL the
# grants withhold must not open by URL either.
class DslAccessControllerTest < ActionController::TestCase
  tests DataRunner::DslsController

  setup do
    session[:user] = {
      'employee_id' => 1, 'email' => 'employee@example.com',
      'first_name' => 'Test', 'last_name' => 'User'
    }
    grant
  end

  # Into Data Runner, but holding no feature of it — the state every existing
  # group lands in until an admin ticks the DSLs it should keep.
  def grant(features: [])
    @controller.define_singleton_method(:current_user_group_names) { Set.new }
    @controller.define_singleton_method(:current_user_application_permission_keys) { Set['data_runner'] }
    @controller.define_singleton_method(:current_user_feature_permission_keys) { Set.new(features) }
    @controller.define_singleton_method(:current_user_dropdown_permissions) { Set.new }
  end

  def dsl_feature(slug) = AppFeature.permission_key('data_runner', AppFeature.dsl_key(slug))

  test 'a DSL the grants withhold does not open by URL' do
    get :show, params: { name: 'employees' }

    assert_redirected_to data_runner_root_path
  end

  test 'the DSL grant opens it' do
    grant(features: [dsl_feature('employees')])

    get :show, params: { name: 'employees' }

    assert_response :success
  end

  test 'a grant on one DSL does not open another' do
    grant(features: [dsl_feature('employees')])

    get :show, params: { name: 'agencies' }

    assert_redirected_to data_runner_root_path
  end

  # Running is the action worth locking down most, and it travels the same
  # member route, so it is covered by the same gate.
  test 'a withheld DSL cannot be run' do
    post :run, params: { name: 'employees' }

    assert_redirected_to data_runner_root_path
  end

  test 'the sidebar lists only the granted DSLs' do
    grant(features: [dsl_feature('employees')])

    get :index

    assert_response :success
    assert_select '.data-runner-sidebar .nav-link[data-dsl-slug=?]', 'employees', count: 1
    assert_select '.data-runner-sidebar .nav-link[data-dsl-slug=?]', 'agencies', count: 0
  end

  test 'holding no DSL leaves the sidebar empty rather than full' do
    get :index

    assert_response :success
    assert_select '.data-runner-sidebar .nav-link[data-dsl-slug]', count: 0
  end

  # Reorganizing the catalog means seeing all of it.
  test 'managing groups opens every DSL' do
    grant(features: [AppFeature.permission_key('data_runner', 'manage_groups')])

    get :show, params: { name: 'employees' }

    assert_response :success
  end
end
