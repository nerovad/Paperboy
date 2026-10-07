# frozen_string_literal: true

require 'test_helper'
require_relative '../support/authorization_console_sign_in'

# Department managers of the parking, badges and keys console appointing and
# removing each other, so the list is kept without an ACL change.
class AuthorizationManagersControllerTest < ActionController::TestCase
  include AuthorizationConsoleSignIn

  setup { AuthorizationManager.delete_all }
  teardown { AuthorizationManager.delete_all }

  test 'a manager removes a fellow manager, and the row records who did it' do
    AuthorizationManager.create!(employee_id: '100', department_id: '4600')
    sign_in_to_console([], own: '4600', employee_id: 100)

    post :create, params: { department_id: '4600', employee_id: '100' }

    assert_match(/already manages/, flash[:alert])

    AuthorizationManager.create!(employee_id: '1', department_id: '4600')
    sign_in_to_console([], own: '4600')

    delete :destroy, params: { id: AuthorizationManager.find_by(employee_id: '100').id }

    assert_equal 'Manager removed.', flash[:notice]
    removed = AuthorizationManager.find_by(employee_id: '100')

    assert_equal '1', removed.removed_by
    assert_not_nil removed.removed_at
    assert_equal ['1'], AuthorizationManager.active.pluck(:employee_id)
  end

  test 'adding a manager records who added them' do
    AuthorizationManager.create!(employee_id: '1', department_id: '4600')
    sign_in_to_console([], own: '4600')

    post :create, params: { department_id: '4600', employee_id: '100' }

    assert_redirected_to authorization_managers_path
    assert_equal '1', AuthorizationManager.active.find_by(employee_id: '100').assigned_by
  end

  test 'a manager cannot appoint anyone to a department they do not manage' do
    AuthorizationManager.create!(employee_id: '1', department_id: '4600')
    sign_in_to_console([], own: '4600')

    post :create, params: { department_id: '5500', employee_id: '200' }
    post :create, params: { department_id: '4600', employee_id: '200' }

    assert_match(/outside the departments you manage/, flash[:alert])
    assert_equal ['1'], AuthorizationManager.pluck(:employee_id)
  end

  test "a manager cannot remove another department's manager" do
    AuthorizationManager.create!(employee_id: '1', department_id: '4600')
    theirs = AuthorizationManager.create!(employee_id: '200', department_id: '5500')
    sign_in_to_console([], own: '4600')

    delete :destroy, params: { id: theirs.id }

    assert_equal 'Manager not found.', flash[:alert]
    assert_nil theirs.reload.removed_at
  end

  test 'the last manager of a department cannot remove themselves' do
    only = AuthorizationManager.create!(employee_id: '1', department_id: '4600')
    sign_in_to_console([], own: '4600')

    delete :destroy, params: { id: only.id }

    assert_match(/needs at least one manager/, flash[:alert])
    assert_nil only.reload.removed_at
  end

  test 'an admin appoints and removes managers anywhere, including the last one' do
    sign_in_to_console(%w[services:read], admin: true)

    post :create, params: { department_id: '5500', employee_id: '100' }
    manager = AuthorizationManager.active.find_by(department_id: '5500', employee_id: '100')

    assert_not_nil manager

    delete :destroy, params: { id: manager.id }

    assert_empty AuthorizationManager.active
  end

  test 'holding the ACL grant over your own department does not make you its manager' do
    sign_in_to_console(%w[services:read services:write services:delete], own: '4600')

    post :create, params: { department_id: '4600', employee_id: '100' }

    assert_redirected_to authorization_console_index_path
    assert_equal 0, AuthorizationManager.count
  end

  test 'someone with no console access is turned away' do
    sign_in_to_console([], own: '4600')

    get :index

    assert_redirected_to root_path
  end

  test 'a removed manager can be appointed again' do
    AuthorizationManager.create!(employee_id: '1', department_id: '4600')
    AuthorizationManager.create!(employee_id: '100', department_id: '4600').remove!(removed_by: '1')
    sign_in_to_console([], own: '4600')

    post :create, params: { department_id: '4600', employee_id: '100' }

    assert_equal 'Manager added.', flash[:notice]
    assert_equal 2, AuthorizationManager.where(employee_id: '100').count
  end

  test 'the managers screen lists each managed department' do
    AuthorizationManager.create!(employee_id: '1', department_id: '4600', assigned_by: '9')
    sign_in_to_console([], own: '4600')

    get :index

    assert_response :success
    assert_select '.approver-card h3', text: /4600 - Department 4600/
    assert_select '.approver-card', count: 1
  end
end

# Looking up who manages what on the managers screen.
class AuthorizationManagersBrowseTest < ActionController::TestCase
  include AuthorizationConsoleSignIn

  tests AuthorizationManagersController

  setup do
    AuthorizationManager.delete_all
    AuthorizationManager.create!(employee_id: '100', department_id: '4600')
    sign_in_to_console(%w[services:read], admin: true)
  end
  teardown { AuthorizationManager.delete_all }

  test 'an admin is shown only the departments that have managers, in a scrolling list' do
    get :index

    assert_select '.approvers-scroll .approver-card', count: 1
    assert_select '.approver-card h3', text: /4600/
    assert_select '.approver-card strong', text: 'Employee 100'
  end

  test 'asking for a department with no managers says so' do
    get :index, params: { filter_department: %w[5500] }

    assert_select '.approver-card', count: 1
    assert_select '.approver-card h3', text: /5500/
    assert_select '.approval-details', text: /No managers assigned/
  end

  test 'the Manager filter lists what that person manages' do
    AuthorizationManager.create!(employee_id: '200', department_id: '5500')

    get :index, params: { filter_manager: %w[200] }

    assert_select '.approver-card', count: 1
    assert_select '.approver-card h3', text: /5500/
    assert_select '.approver-card strong', text: 'Employee 200'
  end

  test 'filters that match nobody say so' do
    get :index, params: { filter_department: %w[5500], filter_manager: %w[100] }

    assert_select '.approver-card', count: 0
    assert_select '.empty-state', text: /No managers match these filters/
  end
end
