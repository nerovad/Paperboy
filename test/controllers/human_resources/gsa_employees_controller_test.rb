# frozen_string_literal: true

require 'test_helper'

module HumanResources
  class GsaEmployeesControllerTest < ActionController::TestCase
    tests HumanResources::GridsController

    setup do
      session[:user] = { 'employee_id' => 42, 'email' => 'hr@example.com',
                         'first_name' => 'Pat', 'last_name' => 'Lee' }
      @controller.define_singleton_method(:current_user_group_names) { Set['staff'] }
      @controller.define_singleton_method(:current_user_application_permission_keys) { ['human_resources'] }
      @controller.define_singleton_method(:current_user_feature_permission_keys) { [] }
      @controller.define_singleton_method(:current_user_dropdown_permissions) { [] }
      @controller.define_singleton_method(:inbox_count) { 0 }
    end

    test 'gsa employees renders the joined column names' do
      GridReader.stub(:count, 1) do
        GridReader.stub(:rows, [['GSA']]) do
          get :show, params: { id: 'gsa_employees' }
        end
      end

      assert_response :success
      assert_select 'h1', text: 'GSA Employee'
      assert_select 'th', text: 'agency_id'
      assert_select 'th', text: 'employee_id'
      assert_select 'th', text: 'unit_id'
      assert_select 'th', text: 'job_code'
      assert_select 'th', text: 'job_title'
      assert_select 'th', text: 'rate_min'
      assert_select 'th', text: 'rate_max'
      assert_select 'section.human-resources-page.human-resources-page--employees'
      assert_select '[data-controller=slideshow]', count: 0
    end
  end
end
