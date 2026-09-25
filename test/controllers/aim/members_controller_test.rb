# frozen_string_literal: true

require 'test_helper'

module Aim
  # Adding and removing the people who work AIM (item a.1).
  class MembersControllerTest < ActionController::TestCase
    tests Aim::MembersController

    setup do
      @employee = Employee.order(:id).first
      skip 'no employee to test with' if @employee.nil?
      session[:user] = { 'email' => 'aim.admin@example.com', 'employee_id' => 42 }
      as_groups 'aim_admin'
    end

    test 'an AIM admin adds a person' do
      post :create, params: { employee_id: @employee.id }

      assert_redirected_to aim_admin_path
      member = Aim::Member.find_by(employee_id: @employee.id)
      assert_equal 'aim.admin@example.com', member.added_by
      assert Aim::Users.member?(@employee.id)
    end

    test 'adding someone twice keeps one row' do
      Aim::Member.create!(employee_id: @employee.id)

      post :create, params: { employee_id: @employee.id }

      assert_match(/already works AIM/, flash[:notice])
      assert_equal 1, Aim::Member.where(employee_id: @employee.id).count
    end

    test 'adding nobody is refused' do
      post :create, params: { employee_id: '' }

      assert_match(/Pick a person/, flash[:alert])
      assert_equal 0, Aim::Member.count
    end

    test 'a person with no open invoices is deleted once their employee id is typed' do
      member = Aim::Member.create!(employee_id: @employee.id)
      Aim::Invoice.create!(actor: 'test', batch_id: 'B-DONE', state: 'exported', assigned_employee_id: @employee.id)

      delete :destroy, params: { id: @employee.id, confirm_employee_id: " #{@employee.id} " }

      assert_redirected_to aim_admin_path
      assert_nil Aim::Member.find_by(id: member.id)
    end

    test 'a delete without the typed employee id is refused' do
      member = Aim::Member.create!(employee_id: @employee.id)

      delete :destroy, params: { id: @employee.id }
      assert_match(/Type .* employee ID/, flash[:alert])

      delete :destroy, params: { id: @employee.id, confirm_employee_id: '1' }
      assert Aim::Member.exists?(member.id)
    end

    test 'a person who still owns invoices is not removed' do
      member = Aim::Member.create!(employee_id: @employee.id)
      Aim::Invoice.create!(actor: 'test', batch_id: 'B-OPEN', state: 'ready_for_approval', assigned_employee_id: @employee.id)

      delete :destroy, params: { id: @employee.id }

      assert_redirected_to aim_member_path(@employee.id)
      assert_match(/still has invoices/, flash[:alert])
      assert Aim::Member.exists?(member.id)
    end

    test 'the employee search reaches people who do not work AIM yet' do
      get :employees, params: { q: @employee.id.to_s }

      assert_equal [@employee.id], response.parsed_body.pluck('value')
    end

    test 'AIM staff do not manage users' do
      as_groups 'aim_staff'

      post :create, params: { employee_id: @employee.id }

      assert_redirected_to aim_root_path
      assert_equal 0, Aim::Member.count
    end

    private

    def as_groups(*names)
      @controller.define_singleton_method(:current_user_group_names) { Set.new(names) }
      @controller.helpers.define_singleton_method(:can_access_app?) { |*| true }
    end
  end
end
