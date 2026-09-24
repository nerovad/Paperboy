# frozen_string_literal: true

require 'test_helper'

module Aim
  class VendorRulesControllerTest < ActionController::TestCase
    tests Aim::VendorRulesController

    setup do
      session[:user] = { 'email' => 'aim.staff@example.com', 'employee_id' => 42 }
      @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    end

    test 'lists rules' do
      Aim::VendorRule.create!(vendor_name: 'Airgas', rules: 'Take the amount due')

      get :index

      assert_response :success
      assert_includes response.body, 'Take the amount due'
    end

    test 'adds, edits and removes rules' do
      post :create, params: { vendor_name: 'Airgas', rules: "one\ntwo" }
      assert_redirected_to aim_vendor_rules_path
      rule = Aim::VendorRule.for_vendor('Airgas')
      assert_equal %w[one two], rule.rule_lines

      patch :update, params: { id: rule.id, rules: 'three' }
      assert_equal ['three'], rule.reload.rule_lines
      assert_equal 'aim.staff@example.com', rule.updated_by

      delete :destroy, params: { id: rule.id }
      assert_nil Aim::VendorRule.find_by(id: rule.id)
    end

    test 'a second set of rules for the same vendor is refused' do
      Aim::VendorRule.create!(vendor_name: 'Airgas', rules: 'x')

      post :create, params: { vendor_name: 'AIRGAS', rules: 'y' }

      assert_match(/taken/, flash[:alert])
      assert_equal 1, Aim::VendorRule.count
    end
  end
end
