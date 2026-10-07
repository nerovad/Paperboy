# frozen_string_literal: true

require 'test_helper'
require_relative '../support/authorization_console_sign_in'

# Budget units with no approver, shown to whoever can see the department.
class AuthorizationCoverageControllerTest < ActionController::TestCase
  include AuthorizationConsoleSignIn

  setup { [AuthorizedApprover, AuthorizationManager].each(&:delete_all) }
  teardown { [AuthorizedApprover, AuthorizationManager].each(&:delete_all) }

  test 'a unit is listed with the service types nobody can approve' do
    AuthorizedApprover.create!(employee_id: '100', department_id: '4600', service_type: 'P', budget_units: '4601')
    sign_in_to_coverage(%w[services:write], own: '4600')

    get :index

    assert_response :success
    assert_select '.approver-card', count: 1
    assert_select '.approval-details strong', text: 'Budget Unit 4601'
    assert_select '.approval-details .value', text: /Employee Identification Badges/
    assert_select '.approval-details .value', text: /Parking Permits/, count: 0
    assert_select '.approval-actions a[href*="budget_unit=4601"]', text: 'Add Approver'
  end

  test 'a fully covered department says so' do
    AuthorizedApprover::SERVICE_TYPES.each_key do |service_type|
      AuthorizedApprover.create!(employee_id: '100', department_id: '4600', service_type: service_type,
                                 key_type: (service_type == 'K' ? '1' : nil), all_budget_units: true)
    end
    sign_in_to_coverage(%w[services:read], own: '4600')

    get :index

    assert_select '.approval-details', text: /Every budget unit has an approver/
  end

  test "a viewer sees no other department's gaps and gets no Add link without write" do
    sign_in_to_coverage(%w[services:read], own: '4600')

    get :index, params: { department_id: %w[5500] }

    assert_select '.approver-card h3', text: /4600/
    assert_select '.approver-card h3', text: /5500/, count: 0
    assert_select '.approval-actions a', count: 0
  end

  private

  def sign_in_to_coverage(keys, own:)
    sign_in_to_console(keys, own: own)
    stub_console(:units_by_department) do |ids|
      AuthorizationConsoleSignIn::UNITS.select { |_unit, department| ids.include?(department) }
                                       .group_by(&:last).transform_values { |pairs| pairs.map(&:first) }
    end
  end
end
