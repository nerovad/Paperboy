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

    def sign_in(*groups)
      session[:user] = { 'email' => 'someone@example.com', 'employee_id' => 7 }
      @controller.define_singleton_method(:current_user_group_names) { Set.new(groups) }
      @controller.helpers.define_singleton_method(:can_access_app?) { |*| true }
    end

    test 'AIM Admins open on the pipeline dashboard, in either mode' do
      sign_in 'aim_admin'
      get :home
      assert_redirected_to aim_dashboard_path

      session[:aim_mode] = 'approver'
      get :home
      assert_redirected_to aim_dashboard_path, 'which shows them My AIM in Approver mode'
    end

    test 'Fiscal open on the Fiscal Dashboard; someone with a queue on My AIM; anyone else on the front page' do
      sign_in
      @controller.helpers.define_singleton_method(:aim_fiscal?) { true }
      get :home
      assert_redirected_to aim_fiscal_dashboard_path

      @controller.helpers.define_singleton_method(:aim_fiscal?) { false }
      @controller.helpers.define_singleton_method(:aim_has_queue?) { true }
      get :home
      assert_redirected_to aim_dashboard_path

      @controller.helpers.define_singleton_method(:aim_has_queue?) { false }
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
