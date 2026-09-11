# frozen_string_literal: true

require 'test_helper'

module HsaAdoptionCards
  class DashboardControllerTest < ActionController::TestCase
    tests HsaAdoptionCards::DashboardController

    setup do
      session[:user] = { 'email' => 'viewer@example.com', 'employee_id' => 42, 'first_name' => 'Sam' }
      @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    end

    test 'the front door is the app slideshow with its own four slides' do
      get :home

      assert_response :success
      assert_select 'img[src*="hsa_adoption_cards/slide_0"]', 5
    end

    test 'a signed-out visitor is sent to the front page' do
      session[:user] = nil
      get :home
      assert_redirected_to root_path
    end
  end
end
