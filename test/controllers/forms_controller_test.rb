require "test_helper"

class FormsControllerTest < ActionDispatch::IntegrationTest
  test "should get home" do
    get forms_home_url
    assert_response :success
  end
end
