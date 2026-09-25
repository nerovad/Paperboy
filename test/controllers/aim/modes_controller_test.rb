# frozen_string_literal: true

require 'test_helper'

module Aim
  # Admin / Approver mode (item a.2): an AIM Admin or Staff member works as a
  # User for the session, and may make that the mode they start in.
  class ModesControllerTest < ActionController::TestCase
    tests Aim::ModesController

    setup do
      session[:user] = { 'email' => 'aim.admin@example.com', 'employee_id' => 42 }
      as_groups 'aim_admin'
    end

    test 'switching to Approver mode lasts for the session and lands on My Queue' do
      patch :update, params: { mode: 'approver' }

      assert_redirected_to aim_my_queue_path
      assert_equal 'approver', session[:aim_mode]
      assert_nil Aim::UserPreference.find_by(employee_id: 42), 'the default is untouched unless asked'
    end

    test 'Start in this mode saves the default' do
      patch :update, params: { mode: 'approver', default: '1' }

      assert_equal 'approver', Aim::UserPreference.start_mode_for(42)
    end

    test 'in Approver mode the admin checks answer as for a User' do
      session[:aim_mode] = 'approver'
      helpers = @controller.helpers

      assert helpers.aim_real_queue_access?
      assert_not helpers.aim_queue_access?
      assert_not helpers.aim_user_admin?
      assert_not helpers.aim_admin?
      assert helpers.aim_has_queue?, 'an admin keeps their own queue to approve from'
    end

    test 'someone with nothing to switch is sent back' do
      as_groups

      patch :update, params: { mode: 'approver' }

      assert_redirected_to aim_root_path
      assert_nil session[:aim_mode]
    end

    test 'the mode someone starts in is their saved default' do
      Aim::UserPreference.create!(employee_id: 42, start_mode: 'approver')

      assert @controller.helpers.aim_approver_mode?
    end

    private

    def as_groups(*names)
      @controller.define_singleton_method(:current_user_group_names) { Set.new(names) }
      @controller.helpers.define_singleton_method(:can_access_app?) { |*| true }
      @controller.helpers.define_singleton_method(:can_use_app_feature?) { |*| false }
    end
  end
end
