# frozen_string_literal: true

require 'test_helper'
require_relative '../support/authorization_console_sign_in'

# Rights in the parking, badges and keys console are held per department: the
# ACL covers a user's own, an AuthorizationManager assignment covers the ones
# it names, and neither spills into the other.
class AuthorizationConsoleDepartmentRightsTest < ActionController::TestCase
  tests AuthorizationConsoleController
  include AuthorizationConsoleSignIn

  setup { [AuthorizedApprover, AuthorizationManager].each(&:delete_all) }
  teardown { [AuthorizedApprover, AuthorizationManager].each(&:delete_all) }

  test 'an assigned manager needs no ACL grant to add an approver' do
    AuthorizationManager.create!(employee_id: '1', department_id: '5500')
    sign_in_to_console([], own: '4600')

    post :create, params: { authorized_approver: approver_params(employee_id: '200', department_id: '5500',
                                                                 budget_units: %w[5501]) }

    assert_equal [%w[200 5500]], AuthorizedApprover.pluck(:employee_id, :department_id)
  end

  test 'an assignment reaches only the assigned department' do
    AuthorizationManager.create!(employee_id: '1', department_id: '5500')
    sign_in_to_console([], own: '4600')

    post :create, params: { authorized_approver: approver_params }

    assert_redirected_to authorization_console_index_path
    assert_match(/outside the departments you manage/, flash[:alert])
    assert_equal 0, AuthorizedApprover.count
  end

  test 'a removed assignment grants nothing' do
    AuthorizationManager.create!(employee_id: '1', department_id: '5500').remove!(removed_by: '9')
    sign_in_to_console([], own: '4600')

    post :create, params: { authorized_approver: approver_params(employee_id: '200', department_id: '5500',
                                                                 budget_units: %w[5501]) }

    assert_redirected_to root_path
    assert_equal 0, AuthorizedApprover.count
  end

  test 'viewing your own department does not let an assigned manager change it' do
    mine = create_approver('100', '4600', '4601')
    AuthorizationManager.create!(employee_id: '1', department_id: '5500')
    sign_in_to_console(%w[services:read], own: '4600')

    delete :group_destroy, params: { ids: [mine.id] }
    patch :group_update, params: { ids: [mine.id], authorized_approver: approver_params(service_type: %w[E]) }

    assert_equal [[mine.id, 'P']], AuthorizedApprover.pluck(:id, :service_type)
  end

  test 'the index offers Edit and Remove only where the user holds them' do
    create_approver('100', '4600', '4601')
    create_approver('200', '5500', '5501')
    AuthorizationManager.create!(employee_id: '1', department_id: '5500')
    sign_in_to_console(%w[services:read], own: '4600')

    get :index

    assert_response :success
    assert_select '.approver-card', count: 2
    assert_select '.approval-actions a', text: 'Edit', count: 1
    assert_select '.approval-actions button', text: /Remove/, count: 1
    assert_select 'a', text: 'Managers', count: 1
  end

  private

  def approver_params(overrides = {})
    { employee_id: '100', department_id: '4600', service_type: %w[P], budget_units: %w[4601] }.merge(overrides)
  end

  def create_approver(employee_id, department_id, unit)
    AuthorizedApprover.create!(employee_id: employee_id, department_id: department_id, service_type: 'P',
                               budget_units: unit, authorized_by: '1')
  end
end
