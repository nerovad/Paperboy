# frozen_string_literal: true

require 'test_helper'
require_relative 'queries_controller_test'

module SqlDashboards
  # Run in the SQL editor: QueriesController#preview.
  class QueryPreviewsControllerTest < ActionController::TestCase
    include TestAccess

    tests SqlDashboards::QueriesController

    QUERY = QueriesControllerTest::QUERY

    setup { sign_in_with_features('sql_dashboard_queries') }

    test 'preview runs unsaved SQL and answers with rows and a chart' do
      assert_no_difference 'Query.count' do
        with_read_only_login { post :preview, params: { query: QUERY } }
      end

      assert_response :success
      assert_select 'turbo-frame#sql_dashboard_preview' do
        assert_select '.sql-result__status', text: /2 rows/
        assert_select '.sql-chart[data-controller="sql-chart"][data-sql-chart-type-value="PieChart"]'
        assert_select '.sql-chart[data-sql-chart-series-value=?]', '[["Open",4],["Closed",2]]'
        assert_select 'table.sql-result__table tbody tr', count: 2
      end
      assert_no_match(/<html/, response.body)
    end

    test 'preview of a saved query uses the SQL in the editor and logs the run against it' do
      query = build_query

      with_read_only_login do
        patch :preview, params: { query_id: query.id, query: QUERY.merge(statement: 'SELECT 7 AS seven') }
      end

      assert_select 'table.sql-result__table td', text: '7'
      assert_equal 'SELECT 1 AS n', query.reload.statement
      assert_equal ['run', query.id, 'SELECT 7 AS seven'],
                   Event.order(:id).last.values_at(:action, :sql_dashboard_query_id, :statement)
    end

    test 'preview shows a SQL error in place of the result' do
      with_read_only_login { post :preview, params: { query: QUERY.merge(statement: 'SELEC nonsense') } }

      assert_response :success
      assert_select '.sql-result__error pre'
      assert_select '.sql-chart', count: 0
    end

    test 'preview says when the rows do not fit the chart, and still lists them' do
      with_read_only_login { post :preview, params: { query: QUERY.merge(statement: "SELECT 'a' AS x, 'b' AS y") } }

      assert_select '.sql-result__notice', text: /needs a number in its second column \(y\)/
      assert_select '.sql-chart', count: 0
      assert_select 'table.sql-result__table tbody tr', count: 1
    end

    test 'preview says when rows were cut at the cap' do
      Database.stub(:row_limit, 1) do
        with_read_only_login { post :preview, params: { query: QUERY.merge(chart_type: 'table') } }
      end

      assert_select '.sql-result__notice', text: /Only the first 1 rows are shown/
      assert_select 'table.sql-result__table tbody tr', count: 1
    end
  end
end
