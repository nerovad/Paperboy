# frozen_string_literal: true

require 'test_helper'

class DataRunnerOutputPaginationTest < ActionController::TestCase
  tests DataRunner::DslsController

  test 'csv output pages with the records series nav' do
    sign_in
    output_path = Rails.root.join('output/data_runner/05_DSL_Applied', 'employees.csv')
    output_path.dirname.mkpath
    total = Pfa::Grid::Table::PAGE_ROWS + 1
    output_path.write("id\n#{(1..total).to_a.join("\n")}\n")

    get :output, params: { name: 'employees', path: '05_DSL_Applied/employees.csv' }

    assert_response :success
    assert_select '.dsl-header .detail-grid h2', text: 'Source'
    assert_select '.dsl-header .detail-grid h2', text: 'Destination'
    assert_select '.dsl-header .detail-grid h2', text: 'Workflow'
    assert_select 'nav.hot-menu'
    assert_select '.output-table-wrap .pfa-grid__scrollport'
    assert_select 'tbody tr', count: Pfa::Grid::Table::PAGE_ROWS
    assert_select '.pagination-wrapper .pagy.series-nav a', text: '<'
    assert_select '.pagination-wrapper .pagy.series-nav a[href*=?]', 'page=2', text: '2'
    assert_match(/Showing 1–#{Pfa::Grid::Table::PAGE_ROWS} of #{total} rows/, response.body)

    get :output, params: { name: 'employees', path: '05_DSL_Applied/employees.csv', page: 2 }

    assert_response :success
    assert_select 'tbody tr', count: 1
    assert_select 'tbody tr td', text: total.to_s
    assert_match(/Showing #{total}–#{total} of #{total} rows/, response.body)
  ensure
    output_path&.delete if output_path&.file?
  end

  private

  def sign_in
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
  end
end
