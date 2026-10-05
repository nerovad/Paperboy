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

  test 'group management sidebar links target the separate ACL workflows' do
    sign_in

    get :index

    assert_response :success
    assert_select '.admin-tools-sidebar > nav > details.nav-group' do
      assert_select '> summary', text: 'ACL'
      assert_select '> a.nav-link', text: 'Global Permissions',
                                    href: org_permissions_acl_index_path
      assert_select '> a.nav-link', text: 'Organizational Permissions',
                                    href: organization_permissions_acl_index_path
      assert_select '> a.nav-link', text: 'Group Management', href: acl_index_path
      assert_select '> a.nav-link', text: 'DAM Access Rules', href: dam_access_rules_path
      assert_select 'details details', count: 0
      assert_select 'a.nav-link', text: /Critical_Info_/, count: 0
    end

    assert_select 'h1', text: 'Group Management'
    assert_select 'details#groups[open]'
    assert_select '.acl-header a.btn', text: /Create New Group/
    html = response.body
    assert_operator html.index('Critical_Info_Admins'), :<, html.index('Critical_Info_Directors')
  end

  test 'organizational permissions page only asks for an organization scope' do
    sign_in

    get :organization_permissions

    assert_response :success
    assert_select 'h1', text: 'Organizational Permissions'
    assert_select '.admin-tools-sidebar a.nav-link.active', text: 'Organizational Permissions'
    assert_select '.acl-header a', count: 0
    assert_select '#organization-scope' do
      assert_select 'select#agency-select'
      assert_select 'select#division-select[disabled]'
      assert_select 'button', text: 'Configure Organizational Permissions'
    end
    assert_select 'input[type=checkbox]', count: 0
  end

  test 'group management divides membership actions into collapsible sections' do
    sign_in

    get :show, params: { id: @admins.GroupID }

    assert_response :success
    assert_select 'details#add-member[open]'
    assert_select 'details#add-contractor:not([open])'
    assert_select 'details#members[open]'
  end

  test 'group permissions are divided into authorization areas' do
    sign_in

    get :permissions, params: { id: @admins.GroupID }

    assert_response :success
    assert_select 'details#application-access[open]' do
      assert_select '#applications'
      assert_select '#application-features'
      assert_select '#authorization-consoles'
      assert_select '#profile-dropdown-items'
    end
    assert_select 'details#records-access' do
      assert_select '#record-view'
      assert_select '#record-edit'
    end
    assert_select 'details#form-workflow' do
      assert_select '#forms'
      assert_select '#submission-actions'
    end
    assert_select 'details#submission-sharing' do
      assert_select '.visibility-grants'
    end
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
