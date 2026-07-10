require 'test_helper'

class FormsControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test 'should get home' do
    get forms_home_url
    assert_response :success
  end

  test 'employee login form includes csrf token' do
    previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    get root_url

    assert_response :success
    assert_select "form[action='#{auth_setup_path}'][method='post']" do
      assert_select "input[name='authenticity_token']", 1
      assert_select "input[type='submit'][value='Employee Login']", 1
    end
  ensure
    ActionController::Base.allow_forgery_protection = previous_forgery_protection
  end
end
