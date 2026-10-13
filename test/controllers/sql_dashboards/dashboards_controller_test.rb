# frozen_string_literal: true

require 'test_helper'

module SqlDashboards
  class DashboardsControllerTest < ActionController::TestCase
    include TestAccess

    tests SqlDashboards::DashboardsController

    setup do
      @dashboard = Dashboard.create!(name: 'Operations')
      @card = @dashboard.cards.create!(query: build_query, position: 1)
    end

    test 'without either grant nothing is reachable' do
      sign_in_with_features

      get :index
      assert_redirected_to root_path

      get :show, params: { id: @dashboard.id }
      assert_redirected_to root_path
    end

    test 'a viewer sees the dashboards but none of the building controls' do
      sign_in_with_features('sql_dashboards')

      get :index
      assert_response :success
      assert_select 'a.sql-dashboards__tile', text: /Operations/
      assert_select 'a[href=?]', sql_dashboards_queries_path, count: 0
      assert_select 'a[href=?]', new_sql_dashboards_dashboard_path, count: 0

      get :show, params: { id: @dashboard.id }
      assert_response :success
      assert_select 'turbo-frame[src=?][loading=lazy]', sql_dashboards_dashboard_card_path(@dashboard, @card)
      assert_select '.sql-card__tools', count: 0
      assert_select 'form.sql-dashboard__add', count: 0
      assert_select 'a[href=?]', edit_sql_dashboards_query_path(@card.query), count: 0
    end

    test 'a viewer cannot make, rename or delete a dashboard' do
      sign_in_with_features('sql_dashboards')

      get :new
      assert_redirected_to sql_dashboards_dashboards_path

      assert_no_difference 'Dashboard.count' do
        post :create, params: { dashboard: { name: 'Sneaky' } }
        delete :destroy, params: { id: @dashboard.id }
      end

      patch :update, params: { id: @dashboard.id, dashboard: { name: 'Renamed' } }
      assert_equal 'Operations', @dashboard.reload.name
    end

    test 'an author sees the building controls' do
      sign_in_with_features('sql_dashboard_queries')

      get :show, params: { id: @dashboard.id }

      assert_response :success
      assert_select '.sql-card__tools'
      assert_select 'form.sql-dashboard__add select[name=?] option', 'card[sql_dashboard_query_id]', count: 2
    end

    test 'an author creates, renames and deletes a dashboard' do
      sign_in_with_features('sql_dashboard_queries')

      post :create, params: { dashboard: { name: 'Billing', description: 'Monthly' } }
      created = Dashboard.order(:id).last
      assert_redirected_to sql_dashboards_dashboard_path(created)
      assert_equal ['Billing', 'Maria Acosta'], [created.name, created.created_by_name]

      patch :update, params: { id: created.id, dashboard: { name: 'Billing 2' } }
      assert_equal 'Billing 2', created.reload.name

      assert_difference 'Dashboard.count', -1 do
        delete :destroy, params: { id: created.id }
      end
    end

    test 'deleting a dashboard keeps its queries' do
      sign_in_with_features('sql_dashboard_queries')

      assert_difference -> { Card.count } => -1, -> { Query.count } => 0 do
        delete :destroy, params: { id: @dashboard.id }
      end
    end

    test 'create without a name shows the form again' do
      sign_in_with_features('sql_dashboard_queries')

      post :create, params: { dashboard: { name: '' } }

      assert_response :unprocessable_entity
      assert_select '.sql-dashboards__errors'
    end
  end
end
