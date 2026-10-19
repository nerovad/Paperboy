# frozen_string_literal: true

module SqlDashboards
  # The SQL editor. Everything here is the `sql_dashboard_queries` grant.
  #
  # #preview runs what is in the editor without saving it. Saving, changing
  # and deleting a query each write an Event; so does every run.
  class QueriesController < BaseController
    before_action :require_author
    before_action :set_query, only: %i[edit update destroy]

    def index
      @queries = Query.alphabetical.includes(:cards)
    end

    def new
      @query = Query.new(database_key: Database.keys.first, chart_type: 'table')
    end

    def edit
      @events = Event.where(sql_dashboard_query_id: @query.id).recent.limit(20)
    end

    def create
      @query = Query.new(query_params.merge(actor_stamp(:created)).merge(actor_stamp(:updated)))
      save_query(:new, 'Query saved.')
    end

    def update
      @query.assign_attributes(query_params.merge(actor_stamp(:updated)))
      save_query(:edit, 'Query saved.')
    end

    def destroy
      Query.transaction do
        Event.record('delete', actor: current_user, query: @query)
        @query.destroy!
      end
      redirect_to sql_dashboards_queries_path, notice: 'Query deleted.'
    end

    def preview
      @query = Query.find_by(id: params[:query_id]) || Query.new
      @query.assign_attributes(query_params)
      @result = Runner.new(@query, actor: current_user).call
      render layout: false
    end

    private

    def set_query
      @query = Query.find(params[:id])
    end

    def save_query(form, notice)
      change = @query.pending_change
      saved = Query.transaction do
        @query.save && (change.nil? || Event.record(change, actor: current_user, query: @query))
      end

      if saved
        redirect_to edit_sql_dashboards_query_path(@query), notice: notice
      else
        @events = Event.none
        render form, status: :unprocessable_entity
      end
    end

    def query_params
      params.expect(query: %i[name description database_key chart_type statement])
    end
  end
end
