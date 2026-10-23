# frozen_string_literal: true

require 'test_helper'

module HumanResources
  class SidebarTest < ActionController::TestCase
    tests HumanResources::DashboardController

    ACTIONS = [
      'Employees',
      'GSA Employee',
      'Bargaining Units',
      'FLSA Status',
      'Job Salaries',
      'Unions',
      'Union codes',
      'VCHRP unions'
    ].freeze

    setup do
      session[:user] = { 'employee_id' => 42, 'email' => 'hr@example.com',
                         'first_name' => 'Pat', 'last_name' => 'Lee' }
      @controller.define_singleton_method(:current_user_group_names) { Set['staff'] }
      @controller.define_singleton_method(:current_user_application_permission_keys) { ['human_resources'] }
      @controller.define_singleton_method(:current_user_feature_permission_keys) { [] }
      @controller.define_singleton_method(:current_user_dropdown_permissions) { [] }
      @controller.define_singleton_method(:inbox_count) { 0 }
    end

    test 'sidebar links open a grid page and the home page keeps the slideshow' do
      get :home

      assert_response :success
      rendered = css_select('.human-resources-links a.nav-link').map { |node| node.text.strip }
      assert_equal ACTIONS, rendered
      assert_select '.human-resources-links a.nav-link[href=?]', human_resources_grid_path('employees'),
                    text: 'Employees'
      assert_select '.human-resources-links button.nav-link', count: 0
      assert_select '.human-resources-links a.nav-link', text: /\AHome\z/, count: 0
      assert_select '.human-resources-links a.nav-link', text: /\AHello World\z/, count: 0
      assert_select '.human-resources-sidebar .pb-modal-backdrop', count: 0
      assert_select '.pb-modal--sidebar-selection', count: 0
      assert_select '[data-controller=slideshow]'
    end

    test 'Refresh Data is the first sidebar action when the grant is held' do
      @controller.define_singleton_method(:current_user_feature_permission_keys) { ['human_resources:data_refresh'] }

      get :home

      assert_response :success
      rendered = css_select('.human-resources-links > a.nav-link').map { |node| node.text.strip }
      assert_equal ['Refresh Data', *ACTIONS], rendered
      assert_select '.human-resources-links > a.nav-link:first-child[href=?]',
                    human_resources_data_refresh_path, text: 'Refresh Data'
    end
  end
end
