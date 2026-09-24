# frozen_string_literal: true

require 'test_helper'

module Aim
  class VendorAliasesControllerTest < ActionController::TestCase
    tests Aim::VendorAliasesController

    setup do
      session[:user] = { 'email' => 'aim.staff@example.com', 'employee_id' => 42 }
      @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    end

    test 'lists aliases and filters them' do
      Aim::VendorAlias.create!(extracted_name: 'AIRGAS USA LLC', normalized_name: 'Airgas')
      Aim::VendorAlias.create!(extracted_name: 'ACME CO', normalized_name: 'Acme')

      get :index, params: { q: 'air' }

      assert_response :success
      assert_equal ['AIRGAS USA LLC'], @controller.instance_variable_get(:@aliases).map(&:extracted_name)
    end

    test 'teaches, corrects and removes an alias' do
      post :create, params: { extracted_name: 'AIRGAS USA LLC', normalized_name: 'Airgas' }
      assert_redirected_to aim_vendor_aliases_path
      row = Aim::VendorAlias.find_by!(extracted_name: 'AIRGAS USA LLC')
      assert_equal 'aim.staff@example.com', row.learned_by

      patch :update, params: { id: row.id, normalized_name: 'Airgas USA' }
      assert_equal 'Airgas USA', row.reload.normalized_name

      delete :destroy, params: { id: row.id }
      assert_nil Aim::VendorAlias.find_by(id: row.id)
    end

    test 'a blank name is refused with the reason' do
      post :create, params: { extracted_name: '', normalized_name: 'Airgas' }

      assert_redirected_to aim_vendor_aliases_path
      assert_match(/required/, flash[:alert])
    end

    test 'access is required' do
      @controller.define_singleton_method(:current_user_group_names) { Set[] }

      get :index

      assert_response :redirect
      assert_match(/do not have access/, flash[:alert])
    end
  end
end
