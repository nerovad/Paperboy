# frozen_string_literal: true

module DataRunner
  class DatabaseDslsController < ApplicationController
    before_action :require_login
    before_action :require_dsl_management

    def new
      assign_form_fields
    end

    def create
      raise DatabaseDslCreator::ImportFailed, 'Set GSABSS_HOST before importing a table.' if source_server.blank?
      raise DatabaseDslCreator::ImportFailed, 'Set SQL22_HOST or SQL22 before replicating a table.' if replicate? && target_server.blank?

      creator = DatabaseDslCreator.new(**creator_params)
      return render_confirmation(creator) unless params[:confirmed] == '1'

      slug = creator.create!
      redirect_to data_runner_dsl_path(slug), notice: "#{slug} DSL created. Run Refresh to copy the rows."
    rescue DatabaseDslCreator::ImportFailed => e
      assign_form_fields
      flash.now[:alert] = e.message
      render :new, status: :unprocessable_entity
    end

    def databases
      render json: catalog.databases(params[:server])
    rescue DataRunnerDatabaseCatalog::ConnectionError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def schemas
      render json: catalog.schemas(params[:server], params[:database])
    rescue DataRunnerDatabaseCatalog::ConnectionError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def tables
      render json: catalog.tables(params[:server], params[:database], schema: params[:schema])
    rescue DataRunnerDatabaseCatalog::ConnectionError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    private

    def render_confirmation(creator)
      @preview = creator.preview!
      render :confirm
    end

    def assign_form_fields
      @server = source_server
      @database = params[:database]
      @table = params[:table]
      @target_server = target_server
      @target_database = params[:target_database].presence || ENV['SQL22_DB'].presence
      @target_schema = params[:target_schema]
      @target_table = params[:target_table]
      @replicate = replicate?
    end

    def database_dsl_params
      params.permit(:server, :database, :table, :replicate, :target_server, :target_database, :target_schema,
                    :target_table)
    end

    def creator_params
      values = database_dsl_params.to_h.symbolize_keys
      values[:server] = source_server
      values[:replicate] = replicate? ? '1' : '0'
      target = {
        server: target_server, database: values.delete(:target_database),
        schema: values.delete(:target_schema), table: values.delete(:target_table)
      }
      values.delete(:target_server)
      values.merge(target: target)
    end

    def replicate?
      params.fetch(:replicate, '1') == '1'
    end

    def source_server
      ENV['GSABSS_HOST'].presence || ENV['MSSQL_HOST'].presence
    end

    def target_server
      ENV['SQL22_HOST'].presence || ENV['SQL22'].presence
    end

    def catalog
      @catalog ||= DataRunnerDatabaseCatalog.new
    end

    def require_dsl_management
      require_app_feature('data_runner', 'manage_groups', fallback: data_runner_root_path)
    end
  end
end
