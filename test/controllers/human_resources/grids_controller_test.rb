# frozen_string_literal: true

require 'test_helper'

module HumanResources
  class GridsControllerTest < ActionController::TestCase
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

    test 'bargaining units renders the dsl columns in a scrolling grid with row navigation' do
      seen = []
      rows = lambda do |_definition, offset:, limit:|
        seen << [offset, limit]
        [%w[10 Clerical]]
      end

      GridReader.stub(:count, Pfa::Grid::Table::PAGE_ROWS + 5) do
        GridReader.stub(:rows, rows) do
          get :show, params: { id: 'bargaining_units' }
        end
      end

      assert_response :success
      assert_equal [[0, Pfa::Grid::Table::PAGE_ROWS]], seen
      assert_select 'turbo-frame#human-resources-grid'
      assert_select '.human-resources-grid .pfa-grid__scrollport'
      assert_select 'th', text: 'bargaining_unit_id'
      assert_select 'th', text: 'description'
      assert_select 'td', text: 'Clerical'
      assert_select 'nav[aria-label="Row navigation"] button[disabled]', text: 'Previous'
      assert_select 'a.btn[href=?]', human_resources_grid_path('bargaining_units', page: 2), text: 'Next'
      assert_match(/Showing 1–#{Pfa::Grid::Table::PAGE_ROWS} of #{Pfa::Grid::Table::PAGE_ROWS + 5} rows/, response.body)
    end

    test 'employees uses the dsl column names' do
      GridReader.stub(:count, 1) do
        GridReader.stub(:rows, [['1']]) do
          get :show, params: { id: 'employees' }
        end
      end

      assert_response :success
      assert_select 'th', text: 'last_name'
      assert_select 'th', text: 'person_email'
      assert_select 'th', text: 'active', count: 0
      assert_select 'nav[aria-label="Row navigation"] button[disabled]', count: 2
      assert_match(/Showing 1–1 of 1 rows/, response.body)
    end

    test 'a missing table is reported in the card' do
      GridReader.stub(:count, ->(*) { raise ActiveRecord::StatementInvalid, 'invalid object' }) do
        get :show, params: { id: 'unions' }
      end

      assert_response :success
      assert_select '.human-resources-grid__error', text: 'unions could not be read.'
      assert_select '.pfa-grid__table', count: 0
    end

    test 'an unknown grid is not found' do
      get :show, params: { id: 'fiscalmonths' }

      assert_response :not_found
    end
  end
end
