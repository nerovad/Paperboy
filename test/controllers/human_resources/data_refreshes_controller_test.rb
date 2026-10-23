# frozen_string_literal: true

require 'test_helper'

module HumanResources
  class DataRefreshesControllerTest < ActionController::TestCase
    tests HumanResources::DataRefreshesController

    setup do
      session[:user] = { 'employee_id' => 42, 'email' => 'hr@example.com',
                         'first_name' => 'Pat', 'last_name' => 'Lee' }
      @controller.define_singleton_method(:current_user_group_names) { Set['staff'] }
      @controller.define_singleton_method(:current_user_application_permission_keys) { ['human_resources'] }
      @controller.define_singleton_method(:current_user_feature_permission_keys) { ['human_resources:data_refresh'] }
      @controller.define_singleton_method(:current_user_dropdown_permissions) { [] }
      @controller.define_singleton_method(:inbox_count) { 0 }
    end

    test 'shows the Human Resources group on the shared refresh form' do
      entry = Struct.new(:key, :slug, :config, :sop) do
        def enabled? = true
      end.new('Employees', 'employees', { source: { location: '/data/employees.csv' } }, nil)

      DslCatalog.stub(:grouped, { 'human_resources' => [entry] }) do
        File.stub(:mtime, Time.zone.local(2026, 8, 2)) do
          get :show
        end
      end

      assert_response :success
      assert_select '.data-refresh-form-header.human-resources-data-refresh-theme h1', text: 'Refresh Data'
      assert_select '.data-refresh-form.human-resources-data-refresh-theme'
      assert_select '.data-refresh-group-trigger', text: /Human Resources/
      assert_select 'input[type=radio][name=?][value=?][checked]', 'groups[human_resources]', '1'
      assert_select 'input[type=submit][value=?]', 'Refresh'
      assert_select 'a.btn[href=?]', human_resources_root_path, text: 'Cancel'
      assert_select '.human-resources-links > a.nav-link.active:first-child[href=?]',
                    human_resources_data_refresh_path, text: 'Refresh Data'
    end

    test 'refuses the refresh screen without the grant' do
      @controller.define_singleton_method(:current_user_feature_permission_keys) { [] }

      DslCatalog.stub(:grouped, { 'human_resources' => [] }) do
        get :show
      end

      assert_redirected_to human_resources_root_path
      assert_equal 'Access denied.', flash[:alert]
    end
  end
end
