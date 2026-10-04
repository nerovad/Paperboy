# frozen_string_literal: true

require 'application_system_test_case'

class ProbationTransferRequestsTest < ApplicationSystemTestCase
  setup do
    sign_in_as_employee
    @probation_transfer_request = probation_transfer_requests(:one)
  end

  test 'visiting the index' do
    visit probation_transfer_requests_url
    assert_selector 'h1', text: 'Probation transfer requests'
  end

  test 'visiting the new request form' do
    visit new_probation_transfer_request_url

    assert_selector 'h1', text: 'Probation Transfer Request'
    assert_field 'Phone'
    assert_button 'Next'
  end

  test 'showing an existing request' do
    visit probation_transfer_request_url(@probation_transfer_request)

    assert_selector 'h1', text: 'Probation Transfer Request'
    assert_link 'Download PDF'
  end
end
