# frozen_string_literal: true

require 'test_helper'

module SqlDashboards
  class CardsControllerTest < ActionController::TestCase
    include TestAccess

    tests SqlDashboards::CardsController

    setup do
      @dashboard = Dashboard.create!(name: 'Operations')
      @query = build_query(chart_type: 'bar', statement: "SELECT 'Jan' AS month, 3 AS requests")
      @card = @dashboard.cards.create!(query: @query, position: 1)
    end

    def frame_id = "result_sql_dashboards_card_#{@card.id}"

    test 'a viewer gets the chart for a card, in its frame and nothing else' do
      sign_in_with_features('sql_dashboards')

      with_read_only_login { get :show, params: { dashboard_id: @dashboard.id, id: @card.id } }

      assert_response :success
      assert_select "turbo-frame##{frame_id}" do
        assert_select '.sql-chart[data-sql-chart-type-value="ColumnChart"][data-sql-chart-series-value=?]',
                      '[["Jan",3]]'
        assert_select 'table', count: 0
      end
      assert_no_match(/<html/, response.body)
    end

    test 'a table card lists its rows' do
      sign_in_with_features('sql_dashboards')
      @query.update!(chart_type: 'table')

      with_read_only_login { get :show, params: { dashboard_id: @dashboard.id, id: @card.id } }

      assert_select 'table.sql-result__table td', text: 'Jan'
    end

    test 'a failing query fails its own card, not the request' do
      sign_in_with_features('sql_dashboards')
      @query.update!(statement: 'SELECT * FROM no_such_table_here')

      with_read_only_login { get :show, params: { dashboard_id: @dashboard.id, id: @card.id } }

      assert_response :success
      assert_select "turbo-frame##{frame_id} .sql-result__error"
    end

    test 'a card without the read-only login says so' do
      sign_in_with_features('sql_dashboards')

      Database.stub(:configured?, false) { get :show, params: { dashboard_id: @dashboard.id, id: @card.id } }

      assert_select '.sql-result__error pre', text: /no read-only login/
    end

    test 'a card is only found on its own dashboard' do
      sign_in_with_features('sql_dashboards')
      other = Dashboard.create!(name: 'Other')

      assert_raises(ActiveRecord::RecordNotFound) { get :show, params: { dashboard_id: other.id, id: @card.id } }
    end

    test 'without a grant a card runs nothing' do
      sign_in_with_features

      assert_no_difference 'Event.count' do
        with_read_only_login { get :show, params: { dashboard_id: @dashboard.id, id: @card.id } }
      end
      assert_redirected_to root_path
    end

    test 'a viewer cannot add, move, resize or remove a card' do
      sign_in_with_features('sql_dashboards')

      assert_no_difference 'Card.count' do
        post :create, params: { dashboard_id: @dashboard.id, card: { sql_dashboard_query_id: @query.id } }
        delete :destroy, params: { dashboard_id: @dashboard.id, id: @card.id }
      end

      patch :update, params: { dashboard_id: @dashboard.id, id: @card.id, card: { width: 'full' } }
      assert_equal 'half', @card.reload.width
    end

    test 'an author adds a card after the last one' do
      sign_in_with_features('sql_dashboard_queries')

      post :create, params: { dashboard_id: @dashboard.id,
                              card: { sql_dashboard_query_id: build_query(name: 'Second').id, width: 'full' } }

      assert_redirected_to sql_dashboards_dashboard_path(@dashboard)
      assert_equal [[1, 'half'], [2, 'full']], @dashboard.cards.reload.pluck(:position, :width)
    end

    test 'adding a card without choosing a query adds nothing' do
      sign_in_with_features('sql_dashboard_queries')

      assert_no_difference 'Card.count' do
        post :create, params: { dashboard_id: @dashboard.id, card: { sql_dashboard_query_id: '' } }
      end
      assert_redirected_to sql_dashboards_dashboard_path(@dashboard)
    end

    test 'an author reorders, resizes and removes a card' do
      sign_in_with_features('sql_dashboard_queries')
      second = @dashboard.cards.create!(query: build_query(name: 'Second'), position: 2)

      patch :update, params: { dashboard_id: @dashboard.id, id: second.id, move: 'up' }
      assert_equal [second, @card], @dashboard.cards.reload.to_a

      patch :update, params: { dashboard_id: @dashboard.id, id: second.id, move: 'down' }
      assert_equal [@card, second], @dashboard.cards.reload.to_a

      patch :update, params: { dashboard_id: @dashboard.id, id: second.id, card: { width: 'full' } }
      assert_equal 'full', second.reload.width

      assert_difference 'Card.count', -1 do
        delete :destroy, params: { dashboard_id: @dashboard.id, id: second.id }
      end
    end
  end
end
