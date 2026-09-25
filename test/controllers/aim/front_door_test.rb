# frozen_string_literal: true

require 'test_helper'

module Aim
  # AIM's front door asks only that someone is signed in; their AIM account
  # decides the rest (Joshua, 2026-09-25).
  class FrontDoorTest < ActionController::TestCase
    tests Aim::DashboardController

    test 'someone signed in without the ACL application grant still gets in' do
      session[:user] = { 'email' => 'someone@example.com', 'employee_id' => 7 }
      @controller.define_singleton_method(:current_user_group_names) { Set[] }
      @controller.helpers.define_singleton_method(:can_access_app?) { |*| false }

      get :home

      assert_response :success
    end

    test 'nobody signed in is sent away' do
      get :home

      assert_redirected_to root_path
    end

    test 'the working dashboard is still for AIM Admins only' do
      session[:user] = { 'email' => 'someone@example.com', 'employee_id' => 7 }
      @controller.define_singleton_method(:current_user_group_names) { Set[] }

      get :index

      assert_redirected_to aim_root_path
    end
  end
end
