# frozen_string_literal: true

require 'test_helper'

class DataRunnerOutputPaginationTest < ActionController::TestCase
  tests DataRunner::DslsController

  test 'csv output pages with the records series nav' do
    sign_in
    total = Pfa::Grid::Table::PAGE_ROWS + 1
    with_applied_employees_csv("id\n#{(1..total).to_a.join("\n")}\n") do
      get :output, params: { name: 'employees', path: '05_DSL_Applied/employees.csv' }

      assert_response :success
      assert_select '.dsl-header .detail-grid h2', text: 'Source'
      assert_select '.dsl-header .detail-grid h2', text: 'Destination'
      assert_select '.dsl-header .detail-grid h2', text: 'Workflow'
      assert_select 'nav.hot-menu'
      assert_select '.output-grid .dsl-header', count: 0
      assert_select '.output-grid .hot-menu', count: 0
      assert_select '.output-grid .output-table-wrap .pfa-grid__scrollport'
      assert_select 'tbody tr', count: Pfa::Grid::Table::PAGE_ROWS
      assert_select '.pagination-wrapper .pagy.series-nav a', text: '<'
      assert_select '.pagination-wrapper .pagy.series-nav a[href*=?]', 'page=2', text: '2'
      assert_match(/Showing 1–#{Pfa::Grid::Table::PAGE_ROWS} of #{total} rows/, response.body)

      get :output, params: { name: 'employees', path: '05_DSL_Applied/employees.csv', page: 2 }

      assert_response :success
      assert_select 'tbody tr', count: 1
      assert_select 'tbody tr td', text: total.to_s
      assert_match(/Showing #{total}–#{total} of #{total} rows/, response.body)
    end
  end

  test 'a large csv offers the next page without a full count' do
    sign_in
    total = Pfa::Grid::Table::PAGE_ROWS + 1
    with_applied_employees_csv("id\n#{(1..total).to_a.join("\n")}\n") do
      WorkflowOutputPresenter.stub(:exact_csv_count?, false) do
        get :output, params: { name: 'employees', path: '05_DSL_Applied/employees.csv' }
      end

      assert_response :success
      assert_select 'tbody tr', count: Pfa::Grid::Table::PAGE_ROWS
      assert_select '.pagination-wrapper .pagy.series-nav a[aria-label=?]', 'Next'
      assert_select '.pagination-wrapper .pagy.series-nav a[href*=?]', 'page=2'
      assert_no_match(/of #{total} rows/, response.body)
      assert_match(/Showing 1–#{Pfa::Grid::Table::PAGE_ROWS}/, response.body)
    end
  end

  private

  # Parallel workers share output/data_runner, and another example deletes
  # employees.csv between this example's two requests.
  def with_applied_employees_csv(body, &block)
    Dir.mktmpdir do |directory|
      root = Pathname(directory)
      path = root.join('05_DSL_Applied/employees.csv')
      path.dirname.mkpath
      path.write(body)
      constructor = WorkflowOutputs.method(:new)
      WorkflowOutputs.stub(:new, ->(entry, **kwargs) { constructor.call(entry, **kwargs, root: root) }, &block)
    end
  end

  def sign_in
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
  end
end
