require "test_helper"

class ParkingLotSubmissionsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get parking_lot_submissions_new_url
    assert_response :success
  end

  test "should get create" do
    get parking_lot_submissions_create_url
    assert_response :success
  end
end
