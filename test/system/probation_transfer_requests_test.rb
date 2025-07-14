require "application_system_test_case"

class ProbationTransferRequestsTest < ApplicationSystemTestCase
  setup do
    @probation_transfer_request = probation_transfer_requests(:one)
  end

  test "visiting the index" do
    visit probation_transfer_requests_url
    assert_selector "h1", text: "Probation transfer requests"
  end

  test "should create probation transfer request" do
    visit probation_transfer_requests_url
    click_on "New probation transfer request"

    fill_in "Agency", with: @probation_transfer_request.agency
    fill_in "Current assignment date", with: @probation_transfer_request.current_assignment_date
    fill_in "Department", with: @probation_transfer_request.department
    fill_in "Desired transfer destination", with: @probation_transfer_request.desired_transfer_destination
    fill_in "Division", with: @probation_transfer_request.division
    fill_in "Email", with: @probation_transfer_request.email
    fill_in "Employee", with: @probation_transfer_request.employee_id
    fill_in "Name", with: @probation_transfer_request.name
    fill_in "Phone", with: @probation_transfer_request.phone
    fill_in "Status", with: @probation_transfer_request.status
    fill_in "Unit", with: @probation_transfer_request.unit
    fill_in "Work location", with: @probation_transfer_request.work_location
    click_on "Create Probation transfer request"

    assert_text "Probation transfer request was successfully created"
    click_on "Back"
  end

  test "should update Probation transfer request" do
    visit probation_transfer_request_url(@probation_transfer_request)
    click_on "Edit this probation transfer request", match: :first

    fill_in "Agency", with: @probation_transfer_request.agency
    fill_in "Current assignment date", with: @probation_transfer_request.current_assignment_date
    fill_in "Department", with: @probation_transfer_request.department
    fill_in "Desired transfer destination", with: @probation_transfer_request.desired_transfer_destination
    fill_in "Division", with: @probation_transfer_request.division
    fill_in "Email", with: @probation_transfer_request.email
    fill_in "Employee", with: @probation_transfer_request.employee_id
    fill_in "Name", with: @probation_transfer_request.name
    fill_in "Phone", with: @probation_transfer_request.phone
    fill_in "Status", with: @probation_transfer_request.status
    fill_in "Unit", with: @probation_transfer_request.unit
    fill_in "Work location", with: @probation_transfer_request.work_location
    click_on "Update Probation transfer request"

    assert_text "Probation transfer request was successfully updated"
    click_on "Back"
  end

  test "should destroy Probation transfer request" do
    visit probation_transfer_request_url(@probation_transfer_request)
    click_on "Destroy this probation transfer request", match: :first

    assert_text "Probation transfer request was successfully destroyed"
  end
end
