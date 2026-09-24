# frozen_string_literal: true

require 'test_helper'

# ACL > group permissions page.
class AclControllerTest < ActionController::TestCase
  setup do
    Forms::Subscription.delete_all
    Forms::VisibilityGrant.delete_all
    @directors = Group.create!(group_name: 'Critical_Info_Directors')
    @admins = Group.create!(group_name: 'Critical_Info_Admins')
  end

  teardown do
    Forms::Subscription.delete_all
    Forms::VisibilityGrant.delete_all
    Group.where(GroupID: [@directors.GroupID, @admins.GroupID]).destroy_all
  end

  # Listing every group's rows made the directors' subscription appear on the
  # admins' page, where its Remove button deleted the directors' row.
  test "a group's page lists only that group's subscriptions and grants" do
    Forms::Subscription.create!(grantee_type: 'group', group_id: @directors.GroupID,
                                form_type: 'CriticalInformationReporting', notify_created: true)
    Forms::VisibilityGrant.create!(grantee_type: 'group', group_id: @directors.GroupID,
                                   form_type: 'CriticalInformationReporting')
    sign_in

    get :permissions, params: { id: @admins.GroupID }

    assert_response :success
    assert_select 'table.visibility-grants-table', count: 0

    get :permissions, params: { id: @directors.GroupID }

    assert_select 'table.visibility-grants-table tbody tr', count: 2
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
