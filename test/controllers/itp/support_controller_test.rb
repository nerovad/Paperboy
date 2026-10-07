# frozen_string_literal: true

require 'test_helper'

module Itp
  class SupportControllerTest < ActionController::TestCase
    tests Itp::SupportController

    setup do
      # current_user is nil unless the session carries BOTH keys, and a nil
      # current_user fails require_app_access before any app code runs.
      session[:user] = { 'email' => 'support@example.com', 'employee_id' => 42, 'first_name' => 'Sam' }
    end

    def grant(*groups)
      names = Set.new(groups)
      @controller.define_singleton_method(:current_user_group_names) { names }
    end

    def grant_features(*keys)
      @controller.define_singleton_method(:current_user_application_permission_keys) { ['itp'] }
      @controller.define_singleton_method(:current_user_feature_permission_keys) { keys }
      @controller.define_singleton_method(:current_user_dropdown_permissions) { [] }
      grant('staff')
    end

    test 'a signed-out visitor is sent to the front page' do
      session[:user] = nil
      get :index
      assert_redirected_to root_path
    end

    test 'holding the app without the support feature lands on the app home' do
      grant_features
      get :index
      assert_redirected_to itp_root_path
    end

    test 'the support feature opens the summary card with the deep-link' do
      grant_features('itp:support')
      get :index
      assert_response :success
      assert_select 'h1', text: 'Support'
      assert_select 'section.itp-support-summary'
      assert_select 'a.btn.secondary[href=?][target=_blank]', Itp::SupportController::DEFAULT_SUPPORT_URL,
                    text: 'Open Support in ITPortal'
    end

    test 'a system admin needs no grants' do
      grant('system_admins')
      get :index
      assert_response :success
    end

    test 'ITPORTAL_SUPPORT_URL overrides the default deep-link' do
      grant_features('itp:support')
      previous = ENV.fetch('ITPORTAL_SUPPORT_URL', nil)
      ENV['ITPORTAL_SUPPORT_URL'] = 'https://gsa-sd-dev/tickets'
      get :index
      assert_response :success
      assert_select 'a.btn.secondary[href=?]', 'https://gsa-sd-dev/tickets'
    ensure
      if previous
        ENV['ITPORTAL_SUPPORT_URL'] = previous
      else
        ENV.delete('ITPORTAL_SUPPORT_URL')
      end
    end
  end
end
