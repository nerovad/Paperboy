# frozen_string_literal: true

require 'test_helper'

module HumanResources
  class SidebarTest < ActionController::TestCase
    tests HumanResources::DashboardController

    ACTIONS = [
      'Employees',
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

    test 'sidebar buttons open a grid card and cancel returns to the slideshow' do
      get :home

      assert_response :success
      rendered = css_select('.human-resources-links button.nav-link').map { |node| node.text.strip }
      assert_equal ACTIONS, rendered
      assert_select '.human-resources-links a.nav-link', count: 0
      assert_select '.human-resources-links button.nav-link', text: /\AHome\z/, count: 0
      assert_select '.human-resources-links button.nav-link', text: /\AHello World\z/, count: 0
      assert_select 'button.nav-link[data-human-resources-sidebar-url-param=?]',
                    human_resources_grid_path('employees'), text: 'Employees'

      assert_select '.pb-modal.pb-modal--sidebar-selection[role=dialog][aria-modal=true]' \
                    '[aria-labelledby=human-resources-selection-title]'
      assert_select '#human-resources-selection-title'
      assert_select 'turbo-frame#human-resources-grid[data-human-resources-sidebar-target=grid]'
      assert_select '.pb-modal__close[aria-label=Close][data-action=?]', 'human-resources-sidebar#dismiss'
      assert_select 'p[data-human-resources-sidebar-target=message]', count: 0
      assert_select '.pb-modal__actions button.btn', text: 'Cancel'
      assert_select '.pb-modal__actions button.btn.approve', count: 0
      assert_select '.pb-modal__actions button[data-action=?]', 'human-resources-sidebar#dismiss', count: 1
      assert_select '[data-human-resources-sidebar-slideshow-url-value=?]', human_resources_root_path
    end

    test 'Refresh Data is the first sidebar action when the grant is held' do
      @controller.define_singleton_method(:current_user_feature_permission_keys) { ['human_resources:data_refresh'] }

      get :home

      assert_response :success
      assert_select '.human-resources-links > a.nav-link:first-child[href=?]',
                    human_resources_data_refresh_path, text: 'Refresh Data'
      rendered = css_select('.human-resources-links button.nav-link').map { |node| node.text.strip }
      assert_equal ACTIONS, rendered
      assert_operator @response.body.index('Refresh Data'), :<, @response.body.index('Employees')
    end
  end
end
