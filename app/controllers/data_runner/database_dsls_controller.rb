# frozen_string_literal: true

module DataRunner
  class DatabaseDslsController < ApplicationController
    before_action :require_login
    before_action :require_dsl_management

    def new
      @server = params[:server].presence || default_server
      @target_server = params[:target_server].presence || default_server
      @target_schema = params[:target_schema].presence || 'dbo'
    end

    def create
      creator = DatabaseDslCreator.new(**creator_params)
      return render_confirmation(creator) unless params[:confirmed] == '1'

      slug = creator.create!
      redirect_to data_runner_dsl_path(slug), notice: "#{slug} DSL imported."
    rescue DatabaseDslCreator::ImportFailed => e
      @server = params[:server]
      @database = params[:database]
      @table = params[:table]
      @target_server = params[:target_server]
      @target_database = params[:target_database]
      @target_schema = params[:target_schema]
      @target_table = params[:target_table]
      flash.now[:alert] = e.message
      render :new, status: :unprocessable_entity
    end

    def databases
      render json: catalog.databases(params[:server])
    rescue DataRunnerDatabaseCatalog::ConnectionError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def tables
      render json: catalog.tables(params[:server], params[:database])
    rescue DataRunnerDatabaseCatalog::ConnectionError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    private

    def render_confirmation(creator)
      @preview = creator.preview!
      render :confirm
    end

    def database_dsl_params
      params.permit(:server, :database, :table, :target_server, :target_database, :target_schema, :target_table)
    end

    def creator_params
      values = database_dsl_params.to_h.symbolize_keys
      target = {
        server: values.delete(:target_server), database: values.delete(:target_database),
        schema: values.delete(:target_schema), table: values.delete(:target_table)
      }
      values.merge(target: target)
    end

    def default_server
      ENV['MSSQL_HOST'].presence || ENV['GSABSS_HOST'].presence
    end

    def catalog
      @catalog ||= DataRunnerDatabaseCatalog.new
    end

    def require_dsl_management
      require_app_feature('data_runner', 'manage_groups', fallback: data_runner_root_path)
    end
  end
end
