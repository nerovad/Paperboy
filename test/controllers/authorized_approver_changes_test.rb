# frozen_string_literal: true

require 'test_helper'
require_relative '../support/authorization_console_sign_in'

# The change log: every add, edit and removal in the parking, badges and keys
# console leaves an entry, and a department's log is read by whoever sees it.
class AuthorizedApproverChangesTest < ActionController::TestCase
  tests AuthorizationConsoleController
  include AuthorizationConsoleSignIn

  setup { [AuthorizedApprover, AuthorizedApproverChange, AuthorizationManager].each(&:delete_all) }
  teardown { [AuthorizedApprover, AuthorizedApproverChange, AuthorizationManager].each(&:delete_all) }

  test 'adding an authorization logs who added it and its scope' do
    sign_in_to_console(%w[services:write], own: '4600')

    post :create, params: { authorized_approver: approver_params(service_type: %w[P E]) }

    change = AuthorizedApproverChange.sole

    assert_equal %w[added 100 4600 1], [change.action, change.employee_id, change.department_id, change.changed_by]
    assert_nil change.scope_before
    assert_equal %w[E P], change.scope_after['service_types']
    assert_includes change.differences, ['Budget Units', '', '4601']
  end

  test 'an edit is one entry showing only what changed, and keeps the original grant' do
    original = AuthorizedApprover.create!(employee_id: '100', department_id: '4600', service_type: 'P',
                                          budget_units: '4601', authorized_by: '77', created_at: 3.days.ago)
    sign_in_to_console(%w[services:write], own: '4600')

    patch :group_update, params: { ids: [original.id], authorized_approver: approver_params(service_type: %w[P E]) }

    change = AuthorizedApproverChange.sole

    assert_equal %w[edited 1], [change.action, change.changed_by]
    assert_equal [['Service Types', 'Parking Permits', 'Employee Identification Badges, Parking Permits']],
                 change.differences
    assert_equal ['77'], AuthorizedApprover.distinct.pluck(:authorized_by)
    assert_operator AuthorizedApprover.maximum(:created_at), :<, 2.days.ago
  end

  test 'an edit that changes nothing logs nothing' do
    original = AuthorizedApprover.create!(employee_id: '100', department_id: '4600', service_type: 'P',
                                          budget_units: '4601', authorized_by: '77')
    sign_in_to_console(%w[services:write], own: '4600')

    patch :group_update, params: { ids: [original.id], authorized_approver: approver_params }

    assert_equal 0, AuthorizedApproverChange.count
  end

  test 'removing an authorization logs what was removed and by whom' do
    original = AuthorizedApprover.create!(employee_id: '100', department_id: '4600', service_type: 'K',
                                          key_type: '2', all_budget_units: true, locations: ['Main Office'])
    sign_in_to_console(%w[services:delete], own: '4600')

    delete :group_destroy, params: { ids: [original.id] }

    change = AuthorizedApproverChange.sole

    assert_equal %w[removed 100 1], [change.action, change.employee_id, change.changed_by]
    assert_nil change.scope_after
    assert_equal [['Service Types', 'Facility Keys and Security Access', ''], ['Key Types', 'Access Cards', ''],
                  ['Budget Units', 'All', ''], ['Locations', 'Main Office', '']], change.differences
  end

  test 'a refused write logs nothing' do
    sign_in_to_console(%w[services:write], own: '4600')

    post :create, params: { authorized_approver: approver_params(department_id: '5500', budget_units: %w[5501]) }

    assert_equal 0, AuthorizedApproverChange.count
  end

  test "the log shows a viewer their own department's changes and nobody else's" do
    log_change('100', '4600')
    log_change('200', '5500')
    @controller = AuthorizedApproverChangesController.new
    sign_in_to_console(%w[services:read], own: '4600')
    stub_console(:employee_names_by_id) { |ids| ids.to_h { |id| [id, "Employee #{id}"] } }

    get :index, params: { department_id: %w[5500] }

    assert_response :success
    assert_select '.approver-card', count: 1
    assert_select '.approver-card h3', text: /Added:\s+Employee 100/

    get :index, format: :csv

    assert_equal 'text/csv', response.media_type
    assert_includes response.body, 'added,100,Employee 100,4600,9,Employee 9,Service Types'
    assert_not_includes response.body, ',5500,'
  end

  test 'the log has no way to change or delete an entry' do
    routes = Rails.application.routes.routes.select { |route| route.defaults[:controller] == 'authorized_approver_changes' }

    assert_equal ['index'], routes.map { |route| route.defaults[:action] }.uniq
  end

  private

  def approver_params(overrides = {})
    { employee_id: '100', department_id: '4600', service_type: %w[P], budget_units: %w[4601] }.merge(overrides)
  end

  def log_change(employee_id, department_id)
    row = AuthorizedApprover.new(employee_id: employee_id, department_id: department_id, service_type: 'P',
                                 budget_units: '')
    AuthorizedApproverChange.record!(action: 'added', changed_by: '9', after: [row])
  end
end
