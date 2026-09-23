# frozen_string_literal: true

require 'test_helper'

module Admin
  class ImpersonationsControllerTest < ActionController::TestCase
    ADMIN_ID = 42

    setup do
      session[:user_id] = ADMIN_ID
      session[:user] = { 'employee_id' => ADMIN_ID, 'email' => 'admin@example.com',
                         'first_name' => 'Real', 'last_name' => 'Admin' }
      @controller.define_singleton_method(:require_admin_tab) { |_key| nil }
      @contractor = Contractor.create!(first_name: 'Casey', last_name: 'Contract', email: 'casey@example.com',
                                       agency: '10', unit: '1001', supervisor_id: ADMIN_ID,
                                       work_phone: '555-0100', expires_at: 1.month.from_now)
    end

    test 'the picker lists contractors, flagging ones who cannot sign in' do
      @contractor.update!(active: false)
      @controller.define_singleton_method(:inbox_count) { 0 }

      Employee.stub(:order, []) { get :new }

      assert_response :success
      assert_select 'optgroup[label=Contractors] option[value=?]', @contractor.id.to_s,
                    text: 'Casey Contract (casey@example.com) - inactive'
    end

    test 'emulating a contractor signs in with the contractor session shape' do
      Submitter.stub(:resolve, @contractor) do
        post :create, params: { employee_id: @contractor.id }
      end

      assert_redirected_to root_path
      assert session[:impersonating]
      assert session[:contractor]
      assert_equal ADMIN_ID, session[:real_admin_id]
      assert_not session[:real_admin_contractor]
      assert_equal @contractor.id, session[:user_id]
      assert_equal({ 'email' => 'casey@example.com', 'first_name' => 'Casey', 'last_name' => 'Contract',
                     'employee_id' => @contractor.id, 'phone' => '555-0100', 'supervisor_id' => ADMIN_ID,
                     'department' => nil, 'agency' => '10', 'unit' => '1001' }, session[:user])
    end

    test 're-emulating keeps the original admin' do
      session[:impersonating] = true
      session[:real_admin_id] = ADMIN_ID
      session[:user_id] = 7

      Submitter.stub(:resolve, @contractor) do
        post :create, params: { employee_id: @contractor.id }
      end

      assert_equal ADMIN_ID, session[:real_admin_id]
    end

    test 'an unknown id is refused' do
      Submitter.stub(:resolve, nil) do
        post :create, params: { employee_id: 999 }
      end

      assert_redirected_to new_admin_impersonation_path
      assert_not session[:impersonating]
    end

    test 'stopping a contractor emulation restores the admin and drops the contractor marker' do
      session[:impersonating] = true
      session[:real_admin_id] = ADMIN_ID
      session[:contractor] = true
      admin = Struct.new(:employee_id, :email, :first_name, :last_name, :work_phone,
                         :supervisor_id, :department, :agency, :unit)
                    .new(ADMIN_ID, 'admin@example.com', 'Real', 'Admin', nil, nil, nil, nil, nil)

      Employee.stub(:find, admin) do
        delete :destroy, params: { id: 1 }
      end

      assert_redirected_to root_path
      assert_not session[:impersonating]
      assert_nil session[:contractor]
      assert_nil session[:real_admin_id]
      assert_equal ADMIN_ID, session[:user_id]
      assert_equal 'admin@example.com', session[:user]['email']
    end
  end
end
