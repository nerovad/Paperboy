# frozen_string_literal: true

require 'test_helper'

class AuthorizedApproverTest < ActiveSupport::TestCase
  setup { AuthorizedApprover.delete_all }

  # One authorization can list budget units from more than one department and
  # is filed under the first. The parking form used to look approvers up by the
  # submitter's department and so missed it, while routing found it by unit.
  test 'an approver filed under one department covers a listed unit in another' do
    AuthorizedApprover.create!(employee_id: '100', department_id: '4600', service_type: 'P',
                               budget_units: '4601,5501')

    assert_equal ['100'], AuthorizedApprover.approver_ids_covering_unit(service_type: 'P', unit_id: '5501')
    assert_includes AuthorizedApprover.authorized_unit_ids_for(employee_id: '100', service_type: 'P'), '5501'
  end

  test 'a unit nobody lists has no approver, whatever the service type' do
    AuthorizedApprover.create!(employee_id: '100', department_id: '4600', service_type: 'E', budget_units: '4601')

    assert_empty AuthorizedApprover.approver_ids_covering_unit(service_type: 'P', unit_id: '4601')
    assert_empty AuthorizedApprover.approver_ids_covering_unit(service_type: 'E', unit_id: '5501')
  end

  # --- coverage ---------------------------------------------------------------

  test 'coverage agrees with routing about which units have an approver' do
    AuthorizedApprover.create!(employee_id: '100', department_id: '4600', service_type: 'P', all_budget_units: true)
    AuthorizedApprover.create!(employee_id: '200', department_id: '4600', service_type: 'E', budget_units: '5501')

    gaps = AuthorizedApprover.coverage_gaps('4600' => %w[4601 4602], '5500' => %w[5501]).transform_values(&:to_h)

    assert_equal %w[E V C K], gaps['4600']['4601']
    assert_equal %w[E V C K], gaps['4600']['4602']
    assert_equal %w[P V C K], gaps['5500']['5501']
    assert_equal ['200'], AuthorizedApprover.approver_ids_covering_unit(service_type: 'E', unit_id: '5501')
  end

  test 'a unit with every service covered is not a gap' do
    AuthorizedApprover::SERVICE_TYPES.each_key do |service_type|
      AuthorizedApprover.create!(employee_id: '100', department_id: '4600', service_type: service_type,
                                 key_type: (service_type == 'K' ? '1' : nil), budget_units: '4601')
    end

    assert_equal({ '4600' => [] }, AuthorizedApprover.coverage_gaps('4600' => %w[4601]))
  end
end
