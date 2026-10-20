# frozen_string_literal: true

module SqlDashboards
  # A query placed on a dashboard. #show runs it and answers with the card's
  # Turbo Frame, so a slow or failing query holds up only its own card.
  class CardsController < BaseController
    before_action :require_viewer, only: :show
    before_action :require_author, except: :show
    before_action :set_dashboard
    before_action :set_card, only: %i[show update destroy]

    def show
      @result = Runner.new(@card.query, actor: current_user).call
      render layout: false
    end

    def create
      card = @dashboard.cards.build(card_params.merge(position: @dashboard.next_position))

      if card.save
        redirect_to sql_dashboards_dashboard_path(@dashboard), notice: 'Card added.'
      else
        redirect_to sql_dashboards_dashboard_path(@dashboard), alert: 'Choose a query to add.'
      end
    end

    def update
      case params[:move]
      when 'up' then @card.move(-1)
      when 'down' then @card.move(1)
      else @card.update(params.expect(card: [:width]))
      end

      redirect_to sql_dashboards_dashboard_path(@dashboard)
    end

    def destroy
      @card.destroy
      redirect_to sql_dashboards_dashboard_path(@dashboard), notice: 'Card removed.'
    end

    private

    def set_dashboard
      @dashboard = Dashboard.find(params[:dashboard_id])
    end

    def set_card
      @card = @dashboard.cards.find(params[:id])
    end

    def card_params
      params.expect(card: %i[sql_dashboard_query_id width])
    end
  end
end
