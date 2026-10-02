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

  test 'ACL sidebar groups access controls and sorts group names' do
    sign_in

    get :index

    assert_response :success
    assert_select '.admin-tools-sidebar > nav > details.nav-group' do
      assert_select '> summary', text: 'ACL'
      assert_select 'details > summary', text: 'Permissions'
      assert_select 'details > summary', text: 'Application Features'
      assert_select 'a.nav-link', text: 'Applications', href: /#organization-permissions$/
      assert_select 'a.nav-link', text: 'DAM Access Rules', href: /#dam-access-rules$/
      assert_select 'a.nav-link', text: 'Group Management', href: /#group-management$/
      assert_select 'details > summary', text: 'Group Management'
      assert_select 'a.nav-link', text: 'Critical_Info_Admins'
      assert_select 'a.nav-link', text: 'Critical_Info_Directors'
      assert_select '.admin-tools-sidebar a.nav-link', text: 'Organization Permissions', count: 0
    end

    assert_select '#global-permissions a.btn', text: 'Configure Global Permissions'
    assert_select '#dam-access-rules a.btn', text: 'Open DAM Access Rules'
    assert_select '#organization-permissions button', text: 'Configure Organization Permissions'
    assert_select '#group-management a.btn', text: /Create New Group/
    html = response.body
    assert_operator html.index('Critical_Info_Admins'), :<, html.index('Critical_Info_Directors')
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
