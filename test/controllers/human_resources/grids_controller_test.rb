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

    test 'bargaining units renders a centered page with search and page numbers' do
      seen = []
      rows = lambda do |_definition, offset:, limit:, query:|
        seen << [offset, limit, query]
        [%w[10 Clerical]]
      end

      GridReader.stub(:count, Pfa::Grid::Table::PAGE_ROWS + 5) do
        GridReader.stub(:rows, rows) do
          get :show, params: { id: 'bargaining_units' }
        end
      end

      assert_response :success
      assert_equal [[0, Pfa::Grid::Table::PAGE_ROWS, '']], seen
      assert_select 'body.has-hero-image', count: 0
      assert_select '[data-controller=slideshow]', count: 0
      assert_select '.human-resources-sidebar .pb-modal-backdrop', count: 0
      assert_select '.human-resources-links a.nav-link.active[href=?]',
                    human_resources_grid_path('bargaining_units'), text: 'Bargaining Units'
      assert_select 'section.human-resources-page h1', text: 'Bargaining Units'
      assert_select 'form.human-resources-grid-search[data-controller=?]' \
                    '[data-human-resources-grid-search-debounce-value=?][data-turbo-frame=?]',
                    'human-resources-grid-search', '250', 'human-resources-grid'
      assert_select 'form.human-resources-grid-search[data-action*=?]',
                    'input->human-resources-grid-search#schedule'
      assert_select 'input[type=search][name=q]'
      assert_select 'turbo-frame#human-resources-grid'
      assert_select '.human-resources-grid .pfa-grid__scrollport'
      assert_select 'th', text: 'bargaining_unit_id'
      assert_select 'th', text: 'description'
      assert_select 'td', text: 'Clerical'
      assert_select '.human-resources-grid .pagy.series-nav a[aria-label=Previous][aria-disabled=true]', text: '<'
      assert_select '.human-resources-grid .pagy.series-nav a[aria-current=page]', text: '1'
      assert_select '.human-resources-grid .pagy.series-nav a[href*=?][href*=?]', 'page=2', 'bargaining_units',
                    text: '2'
      assert_select '.human-resources-grid .pagy.series-nav a[aria-label=Next]', text: '>'
      assert_match(/Showing 1–#{Pfa::Grid::Table::PAGE_ROWS} of #{Pfa::Grid::Table::PAGE_ROWS + 5} rows/, response.body)
    end

    test 'a search is applied to the page and kept on the page links' do
      seen = []
      count = lambda do |_definition, query:|
        seen << [:count, query]
        Pfa::Grid::Table::PAGE_ROWS + 5
      end
      rows = lambda do |_definition, offset:, limit:, query:|
        seen << [:rows, offset, limit, query]
        [%w[10 Clerical]]
      end

      GridReader.stub(:count, count) do
        GridReader.stub(:rows, rows) do
          get :show, params: { id: 'bargaining_units', q: 'sm', page: '2' }
        end
      end

      assert_response :success
      assert_equal [[:count, 'sm'], [:rows, Pfa::Grid::Table::PAGE_ROWS, Pfa::Grid::Table::PAGE_ROWS, 'sm']], seen
      assert_select 'input[name=q][value=sm]'
      assert_select '.human-resources-links a.nav-link.active[href=?]', human_resources_grid_path('bargaining_units')
      previous = css_select('.pagy.series-nav a[aria-label=Previous]').first
      assert_includes previous['href'], 'page=1'
      assert_includes previous['href'], 'q=sm'
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
      assert_select '.pagy.series-nav a[aria-label=Previous][aria-disabled=true]', text: '<'
      assert_select '.pagy.series-nav a[aria-current=page]', text: '1'
      assert_select '.pagy.series-nav a[aria-label=Next][aria-disabled=true]', text: '>'
      assert_match(/Showing 1–1 of 1 rows/, response.body)
    end

    test 'a missing table is reported on the page' do
      missing = ->(_definition, query:) { raise ActiveRecord::StatementInvalid, query.to_s }
      GridReader.stub(:count, missing) do
        get :show, params: { id: 'unions' }
      end

      assert_response :success
      assert_select '.human-resources-grid__error', text: 'unions could not be read.'
      assert_select '.pfa-grid__table', count: 0
      assert_select '[data-controller=slideshow]', count: 0
    end

    test 'an unknown grid is not found' do
      get :show, params: { id: 'fiscalmonths' }

      assert_response :not_found
    end
  end
end
