# frozen_string_literal: true

module SqlDashboards
  # The dashboards themselves: a list, a page of cards, and the screens that
  # name one. Each card fetches its own chart (CardsController#show).
  class DashboardsController < BaseController
    before_action :require_viewer, only: %i[index show]
    before_action :require_author, except: %i[index show]
    before_action :set_dashboard, only: %i[show edit update destroy]

    def index
      @dashboards = Dashboard.alphabetical
    end

    def show
      @cards = @dashboard.cards.includes(:query)
      @queries = Query.alphabetical if helpers.sql_dashboards_author?
    end

    def new
      @dashboard = Dashboard.new
    end

    def edit; end

    def create
      @dashboard = Dashboard.new(dashboard_params.merge(actor_stamp(:created)))

      if @dashboard.save
        redirect_to sql_dashboards_dashboard_path(@dashboard), notice: 'Dashboard created.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @dashboard.update(dashboard_params)
        redirect_to sql_dashboards_dashboard_path(@dashboard), notice: 'Dashboard updated.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @dashboard.destroy
      redirect_to sql_dashboards_dashboards_path, notice: 'Dashboard deleted.'
    end

    private

    def set_dashboard
      @dashboard = Dashboard.find(params[:id])
    end

    def dashboard_params
      params.expect(dashboard: %i[name description])
    end
  end
end
