# frozen_string_literal: true

require 'test_helper'

module SqlDashboards
  # The SQL editor: the `sql_dashboard_queries` feature grant.
  class QueriesControllerTest < ActionController::TestCase
    include TestAccess

    tests SqlDashboards::QueriesController

    QUERY = { name: 'Requests by status', database_key: 'paperboy', chart_type: 'pie',
              statement: "SELECT 'Open' AS status, 4 AS total UNION ALL SELECT 'Closed', 2" }.freeze

    setup { sign_in_with_features('sql_dashboard_queries') }

    test 'the viewing grant alone reaches nothing here' do
      sign_in_with_features('sql_dashboards')
      query = build_query

      get :index
      assert_redirected_to sql_dashboards_dashboards_path

      get :edit, params: { id: query.id }
      assert_redirected_to sql_dashboards_dashboards_path

      assert_no_difference ['Query.count', 'Event.count'] do
        post :create, params: { query: QUERY }
        with_read_only_login { post :preview, params: { query: QUERY } }
        delete :destroy, params: { id: query.id }
      end
    end

    test 'no grant at all is sent home' do
      sign_in_with_features

      get :index
      assert_redirected_to root_path
    end

    test 'the editor offers Paperboy and GSABSS and no other database' do
      get :new

      assert_response :success
      assert_select 'select[name=?] option', 'query[database_key]', count: 2
      assert_select 'select[name=?] option[value=billing]', 'query[database_key]', count: 0
      assert_select 'select[name=?] option', 'query[chart_type]', count: 5
      assert_select 'turbo-frame#sql_dashboard_preview'
    end

    test 'create saves the query and logs who made it' do
      assert_difference ['Query.count', 'Event.count'], 1 do
        post :create, params: { query: QUERY }
      end

      query = Query.order(:id).last
      event = Event.order(:id).last

      assert_redirected_to edit_sql_dashboards_query_path(query)
      assert_equal ['102989', 'Maria Acosta'], [query.created_by_id, query.updated_by_name]
      assert_equal ['create', query.id, 'Maria Acosta', QUERY[:statement]],
                   [event.action, event.sql_dashboard_query_id, event.employee_name, event.statement]
    end

    test 'create without SQL shows the editor again' do
      assert_no_difference ['Query.count', 'Event.count'] do
        post :create, params: { query: QUERY.merge(statement: '') }
      end

      assert_response :unprocessable_entity
      assert_select '.sql-dashboards__errors'
    end

    test 'update logs a change and keeps the SQL as it now is' do
      query = build_query

      assert_difference 'Event.count', 1 do
        patch :update, params: { id: query.id, query: { statement: 'SELECT 2 AS n' } }
      end

      assert_equal 'SELECT 2 AS n', query.reload.statement
      assert_equal ['update', 'SELECT 2 AS n'], Event.order(:id).last.values_at(:action, :statement)
    end

    test 'saving without a change logs nothing' do
      query = build_query

      assert_no_difference 'Event.count' do
        patch :update, params: { id: query.id, query: { name: query.name } }
      end
    end

    test 'destroy logs the query it removes' do
      query = build_query

      assert_difference -> { Query.count } => -1, -> { Event.count } => 1 do
        delete :destroy, params: { id: query.id }
      end

      assert_redirected_to sql_dashboards_queries_path
      assert_equal ['delete', query.id, 'SELECT 1 AS n'],
                   Event.order(:id).last.values_at(:action, :sql_dashboard_query_id, :statement)
    end

    test 'edit lists the recent activity on a query' do
      query = build_query
      Event.record('update', actor: @controller.current_user, query: query)

      get :edit, params: { id: query.id }

      assert_response :success
      assert_select 'h2', text: 'Recent activity'
      assert_select 'td', text: 'Maria Acosta'
    end
  end
end
