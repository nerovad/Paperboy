# frozen_string_literal: true

require 'test_helper'
require_relative '../support/authorization_console_sign_in'

# Budget units with no approver, listed on the console page for whoever can
# see the department once "Show units with no approvers" is ticked.
class AuthorizationConsoleGapsTest < ActionController::TestCase
  include AuthorizationConsoleSignIn

  tests AuthorizationConsoleController

  setup { [AuthorizedApprover, AuthorizationManager].each(&:delete_all) }
  teardown { [AuthorizedApprover, AuthorizationManager].each(&:delete_all) }

  test 'the gaps stay hidden until asked for, with their count on the checkbox' do
    AuthorizedApprover.create!(employee_id: '100', department_id: '4600', service_type: 'P', budget_units: '4601')
    sign_in_to_console(%w[services:write], own: '4600')

    get :index

    assert_response :success
    assert_select 'input[type=checkbox][name=show_gaps]:not([checked])'
    assert_select 'label.filter-toggle', text: /Show units with no approvers \(1\)/
    assert_select '.coverage-gaps', count: 0
  end

  test 'a unit is listed with the service types nobody can approve' do
    AuthorizedApprover.create!(employee_id: '100', department_id: '4600', service_type: 'P', budget_units: '4601')
    sign_in_to_console(%w[services:write], own: '4600')

    get :index, params: { show_gaps: '1' }

    assert_select 'input[type=checkbox][name=show_gaps][checked]'
    assert_select '.coverage-gaps .approval-details strong', text: 'Budget Unit 4601'
    assert_select '.coverage-gaps .approval-details .value', text: /Employee Identification Badges/
    assert_select '.coverage-gaps .approval-details .value', text: /Parking Permits/, count: 0
    assert_select '.coverage-gaps .approval-actions a[href*="budget_unit=4601"]', text: 'Add Approver'
  end

  test 'the Service Type filter narrows the gaps and their count' do
    AuthorizedApprover.create!(employee_id: '100', department_id: '4600', service_type: 'P', budget_units: '4601')
    sign_in_to_console(%w[services:read], own: '4600')

    get :index, params: { show_gaps: '1', service_type: %w[P] }

    assert_select 'label.filter-toggle', text: /\(0\)/
    assert_select '.coverage-gaps .approver-card', count: 0
    assert_select '.coverage-gaps', text: /Every budget unit has an approver/
  end

  test "a viewer sees no other department's gaps and gets no Add link without write" do
    sign_in_to_console(%w[services:read], own: '4600')

    get :index, params: { show_gaps: '1', department_id: %w[5500] }

    assert_select '.coverage-gaps .approver-card h3', text: /4600/
    assert_select '.coverage-gaps .approver-card h3', text: /5500/, count: 0
    assert_select '.coverage-gaps .approval-actions a', count: 0
  end
end
