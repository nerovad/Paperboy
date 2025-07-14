require "test_helper"

class ProbationTransferRequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @probation_transfer_request = probation_transfer_requests(:one)
  end

  test "should get index" do
    get probation_transfer_requests_url
    assert_response :success
  end

  test "should get new" do
    get new_probation_transfer_request_url
    assert_response :success
  end

  test "should create probation_transfer_request" do
    assert_difference("ProbationTransferRequest.count") do
      post probation_transfer_requests_url, params: { probation_transfer_request: { agency: @probation_transfer_request.agency, current_assignment_date: @probation_transfer_request.current_assignment_date, department: @probation_transfer_request.department, desired_transfer_destination: @probation_transfer_request.desired_transfer_destination, division: @probation_transfer_request.division, email: @probation_transfer_request.email, employee_id: @probation_transfer_request.employee_id, name: @probation_transfer_request.name, phone: @probation_transfer_request.phone, status: @probation_transfer_request.status, unit: @probation_transfer_request.unit, work_location: @probation_transfer_request.work_location } }
    end

    assert_redirected_to probation_transfer_request_url(ProbationTransferRequest.last)
  end

  test "should show probation_transfer_request" do
    get probation_transfer_request_url(@probation_transfer_request)
    assert_response :success
  end

  test "should get edit" do
    get edit_probation_transfer_request_url(@probation_transfer_request)
    assert_response :success
  end

  test "should update probation_transfer_request" do
    patch probation_transfer_request_url(@probation_transfer_request), params: { probation_transfer_request: { agency: @probation_transfer_request.agency, current_assignment_date: @probation_transfer_request.current_assignment_date, department: @probation_transfer_request.department, desired_transfer_destination: @probation_transfer_request.desired_transfer_destination, division: @probation_transfer_request.division, email: @probation_transfer_request.email, employee_id: @probation_transfer_request.employee_id, name: @probation_transfer_request.name, phone: @probation_transfer_request.phone, status: @probation_transfer_request.status, unit: @probation_transfer_request.unit, work_location: @probation_transfer_request.work_location } }
    assert_redirected_to probation_transfer_request_url(@probation_transfer_request)
  end

  test "should destroy probation_transfer_request" do
    assert_difference("ProbationTransferRequest.count", -1) do
      delete probation_transfer_request_url(@probation_transfer_request)
    end

    assert_redirected_to probation_transfer_requests_url
  end
end
