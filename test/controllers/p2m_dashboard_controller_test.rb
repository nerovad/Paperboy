# frozen_string_literal: true

require 'test_helper'

class P2mDashboardControllerTest < ActionController::TestCase
  tests P2m::DashboardController

  test 'opening print 2 mail shows the slideshow' do
    sign_in

    get :home

    assert_response :success
    assert_select '.slideshow[data-controller="slideshow"]'
    assert_select 'img[alt="Ventura Pier"]'
    assert_select 'p', text: /Hello World/, count: 0
  end

  test 'the hello world dashboard route is gone' do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path('/p2m/dashboard')
    end
  end

  test 'a visitor without print 2 mail is sent away' do
    get :home

    assert_redirected_to root_path
  end

  private

  def sign_in
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
    @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
  end
end
