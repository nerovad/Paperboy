# frozen_string_literal: true

require 'test_helper'

class ProbationTransferRequestsControllerTest < ActionController::TestCase
  tests Forms::ProbationTransferRequestsController

  # Every page needs a signed-in user (ApplicationController#require_sign_in).
  setup do
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
    @probation_transfer_request = probation_transfer_requests(:one)
  end

  test 'should get index' do
    get :index
    assert_response :success
  end

  test 'should get new' do
    get :new
    assert_response :success
  end

  test 'should create probation_transfer_request' do
    assert_difference('ProbationTransferRequest.count') do
      post :create,
           params: { probation_transfer_request: { agency: @probation_transfer_request.agency, current_assignment_date: @probation_transfer_request.current_assignment_date,
                                                   department: @probation_transfer_request.department, desired_transfer_destination: @probation_transfer_request.desired_transfer_destination, division: @probation_transfer_request.division, email: @probation_transfer_request.email, employee_id: @probation_transfer_request.employee_id, name: @probation_transfer_request.name, phone: @probation_transfer_request.phone, status: @probation_transfer_request.status, unit: @probation_transfer_request.unit, work_location: @probation_transfer_request.work_location } }
    end

    assert_redirected_to probation_transfer_request_path(ProbationTransferRequest.last)
  end

  test 'should show probation_transfer_request' do
    get :show, params: { id: @probation_transfer_request.id }
    assert_response :success
  end

  test 'should get edit' do
    get :edit, params: { id: @probation_transfer_request.id }
    assert_response :success
  end

  test 'should update probation_transfer_request' do
    patch :update,
          params: { id: @probation_transfer_request.id, probation_transfer_request: { agency: @probation_transfer_request.agency, current_assignment_date: @probation_transfer_request.current_assignment_date,
                                                                                      department: @probation_transfer_request.department, desired_transfer_destination: @probation_transfer_request.desired_transfer_destination, division: @probation_transfer_request.division, email: @probation_transfer_request.email, employee_id: @probation_transfer_request.employee_id, name: @probation_transfer_request.name, phone: @probation_transfer_request.phone, status: @probation_transfer_request.status, unit: @probation_transfer_request.unit, work_location: @probation_transfer_request.work_location } }
    assert_redirected_to probation_transfer_request_path(@probation_transfer_request)
  end

  test 'should destroy probation_transfer_request' do
    assert_difference('ProbationTransferRequest.count', -1) do
      delete :destroy, params: { id: @probation_transfer_request.id }
    end

    assert_redirected_to probation_transfer_requests_path
  end
end
