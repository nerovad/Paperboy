require "test_helper"

class ParkingLotControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get parking_lot_index_url
    assert_response :success
  end
end
