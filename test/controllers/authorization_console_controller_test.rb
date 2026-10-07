# frozen_string_literal: true

require 'test_helper'
require_relative '../support/authorization_console_sign_in'

# The parking, badges and keys console. A department-scoped user sees only
# their own department; these hold every write to that same scope, because a
# posted form is not bound by the pickers it was rendered with.
class AuthorizationConsoleControllerTest < ActionController::TestCase
  include AuthorizationConsoleSignIn

  setup { AuthorizedApprover.delete_all }
  teardown { AuthorizedApprover.delete_all }

  test 'a department user adds an approver in their own department' do
    sign_in_to_console(%w[services:write], departments: %w[4600])

    post :create, params: { authorized_approver: approver_params }

    assert_redirected_to authorization_console_index_path(department_id: '4600')
    assert_equal [%w[100 4600 P]], AuthorizedApprover.pluck(:employee_id, :department_id, :service_type)
  end

  test 'a department user cannot add an approver over another department' do
    sign_in_to_console(%w[services:write], departments: %w[4600])

    post :create, params: { authorized_approver: approver_params(department_id: '5500', budget_units: []) }

    assert_denied
  end

  test "a department user cannot add another department's budget unit" do
    sign_in_to_console(%w[services:write], departments: %w[4600])

    post :create, params: { authorized_approver: approver_params(budget_units: %w[4601 5501]) }

    assert_denied
  end

  test "a department user cannot authorize another department's employee" do
    sign_in_to_console(%w[services:write], departments: %w[4600])

    post :create, params: { authorized_approver: approver_params(employee_id: '200') }

    assert_denied
  end

  test 'an admin adds an approver in any department' do
    sign_in_to_console(%w[services:write], departments: %w[4600 5500])

    post :create, params: { authorized_approver: approver_params(employee_id: '200', department_id: '5500',
                                                                 budget_units: %w[5501]) }

    assert_equal [%w[200 5500]], AuthorizedApprover.pluck(:employee_id, :department_id)
  end

  test 'an edit cannot move an authorization into another department' do
    mine = create_approver('100', '4600', '4601')
    sign_in_to_console(%w[services:write], departments: %w[4600])

    patch :group_update, params: { ids: [mine.id], authorized_approver: approver_params(budget_units: %w[5501]) }

    assert_redirected_to authorization_console_index_path
    assert_match(/outside the departments you manage/, flash[:alert])
    assert_equal '4601', mine.reload.budget_units
  end

  test 'an edit keeps an employee who has since left the department' do
    moved = create_approver('200', '4600', '4601')
    sign_in_to_console(%w[services:write], departments: %w[4600])

    patch :group_update, params: { ids: [moved.id],
                                   authorized_approver: approver_params(employee_id: '200', service_type: %w[E]) }

    assert_equal [%w[200 E]], AuthorizedApprover.pluck(:employee_id, :service_type)
  end

  test "an edit naming another department's authorization changes nothing" do
    theirs = create_approver('200', '5500', '5501')
    sign_in_to_console(%w[services:write], departments: %w[4600])

    patch :group_update, params: { ids: [theirs.id], authorized_approver: approver_params }

    assert_redirected_to authorization_console_index_path
    assert_equal 'Authorization not found.', flash[:alert]
    assert_equal [theirs.id], AuthorizedApprover.pluck(:id)
  end

  test "a department user cannot remove another department's authorization" do
    mine = create_approver('100', '4600', '4601')
    theirs = create_approver('200', '5500', '5501')
    sign_in_to_console(%w[services:delete], departments: %w[4600])

    delete :group_destroy, params: { ids: [mine.id, theirs.id] }

    assert_equal [theirs.id], AuthorizedApprover.pluck(:id)
  end

  test 'write does not grant remove, and remove does not grant write' do
    mine = create_approver('100', '4600', '4601')
    sign_in_to_console(%w[services:write], departments: %w[4600])

    delete :group_destroy, params: { ids: [mine.id] }

    assert_match(/do not have delete access/, flash[:alert])
    assert AuthorizedApprover.exists?(mine.id)

    sign_in_to_console(%w[services:delete], departments: %w[4600])

    post :create, params: { authorized_approver: approver_params(employee_id: '100', service_type: %w[E]) }

    assert_match(/do not have write access/, flash[:alert])
    assert_equal 1, AuthorizedApprover.count
  end

  test 'a user holding nothing on the console is turned away' do
    sign_in_to_console([], departments: %w[4600])

    post :create, params: { authorized_approver: approver_params }

    assert_redirected_to root_path
    assert_equal 0, AuthorizedApprover.count
  end

  private

  def approver_params(overrides = {})
    { employee_id: '100', department_id: '4600', service_type: %w[P], budget_units: %w[4601] }.merge(overrides)
  end

  def create_approver(employee_id, department_id, unit)
    AuthorizedApprover.create!(employee_id: employee_id, department_id: department_id, service_type: 'P',
                               budget_units: unit, authorized_by: '1')
  end

  def assert_denied
    assert_redirected_to authorization_console_index_path
    assert_match(/outside the departments you manage/, flash[:alert])
    assert_equal 0, AuthorizedApprover.count
  end
end
