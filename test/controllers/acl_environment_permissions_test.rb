# frozen_string_literal: true

require 'test_helper'

# ACL > group permissions > Test Environments.
class AclEnvironmentPermissionsTest < ActionController::TestCase
  tests AclController

  setup do
    @group = Group.create!(group_name: 'Environment_Acl_Testers')
  end

  teardown do
    GroupPermission.where(group_id: @group.GroupID).delete_all
    @group.destroy
  end

  test 'test environment grants are offered, saved, and anything unknown is dropped' do
    sign_in

    patch :update_permissions, params: { id: @group.GroupID, environment_permissions: %w[stage production] }

    assert_redirected_to permissions_acl_path(@group)
    assert_equal [%w[environment stage]], @group.group_permissions.pluck(:permission_type, :permission_key)

    get :permissions, params: { id: @group.GroupID }

    assert_select 'details#test-environments' do
      assert_select 'input[name=?][value=stage][checked]', 'environment_permissions[]'
      assert_select 'input[name=?][value=dev]:not([checked])', 'environment_permissions[]'
    end
  end

  test 'the organization screen offers the same grants' do
    sign_in

    get :org_permissions

    assert_response :success
    assert_select 'details#test-environments input[name=?]', 'environment_permissions[]', count: 2
  end

  private

  def sign_in
    session[:user] = { 'employee_id' => 1, 'email' => 'admin@example.com',
                       'first_name' => 'Test', 'last_name' => 'Admin' }
    @controller.define_singleton_method(:current_user_group_names) { Set.new }
    @controller.define_singleton_method(:current_user_group_ids) { [] }
    @controller.define_singleton_method(:current_user_org_chain) { {} }
    @controller.define_singleton_method(:current_user_feature_permission_keys) { Set['admin_tools:acl'] }
    @controller.define_singleton_method(:current_user_dropdown_permissions) { Set.new }
  end
end
