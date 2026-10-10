# frozen_string_literal: true

require 'test_helper'

# ApplicationController#require_environment_access, exercised through a
# controller that does nothing else.
class EnvironmentAccessGateTest < ActionController::TestCase
  class ProbeController < ApplicationController
    def show
      render plain: 'inside'
    end
  end

  tests ProbeController

  setup do
    @group = Group.create!(group_name: 'Environment_Gate_Testers')
  end

  teardown do
    GroupPermission.where(group_id: @group.GroupID).delete_all
    @group.destroy
  end

  test 'a signed-in user without the grant is sent to the landing page' do
    sign_in

    on_environment('stage') { get :show }

    assert_response :see_other
    assert_redirected_to '/environment_access'
  end

  test 'a request that cannot show a page is refused instead of redirected' do
    sign_in

    on_environment('stage') { get :show, format: :json }
    assert_response :forbidden

    @request.headers['Turbo-Frame'] = 'who_am_i'
    on_environment('stage') { get :show }
    assert_response :forbidden
  end

  test 'a group grant for this environment lets its members in' do
    grant('stage')
    sign_in(group_ids: [@group.GroupID])

    on_environment('stage') { get :show }

    assert_response :success
    assert_equal 'inside', response.body
  end

  test 'a grant for the other environment does not' do
    grant('dev')
    sign_in(group_ids: [@group.GroupID])

    on_environment('stage') { get :show }

    assert_redirected_to '/environment_access'
  end

  test 'a system admin is never kept out' do
    sign_in(group_names: Set['system_admins'])

    on_environment('dev') { get :show }

    assert_response :success
  end

  test 'an emulation passes whoever is being emulated' do
    sign_in
    session[:impersonating] = true
    session[:real_admin_id] = 7

    on_environment('stage') { get :show }

    assert_response :success
  end

  test 'an environment that asks for no grant is not gated' do
    sign_in

    on_environment(nil) { get :show }

    assert_response :success
  end

  test 'a signed-out visitor is still asked to sign in first' do
    on_environment('stage') { get :show }

    assert_redirected_to '/'
  end

  private

  def sign_in(group_names: Set.new, group_ids: [])
    session[:user] = { 'employee_id' => 1, 'email' => 'tester@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
    @controller.define_singleton_method(:current_user_group_names) { group_names }
    @controller.define_singleton_method(:current_user_group_ids) { group_ids }
    @controller.define_singleton_method(:current_user_org_chain) { {} }
  end

  def grant(key)
    @group.group_permissions.create!(permission_type: EnvironmentAccess::PERMISSION_TYPE, permission_key: key)
  end

  def on_environment(key, &block)
    with_routing do |set|
      set.draw do
        root to: 'environment_access_gate_test/probe#show'
        get '/probe', to: 'environment_access_gate_test/probe#show'
        get '/environment_access', to: 'environment_access#show', as: :environment_access
      end
      EnvironmentAccess.stub(:key_for, key, &block)
    end
  end
end
