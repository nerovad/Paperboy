# frozen_string_literal: true

module P2m
  class DataResetsController < ApplicationController
    before_action -> { require_app_feature('p2m', 'data_reset', fallback: p2m_root_path) }

    def show
      @results = DataReset.new.preview
      prepare_results
    end

    def create
      return reset_target if params[:target].present?

      reset = DataReset.new
      reset.call
      @results = reset.preview
      prepare_results
      flash.now[:notice] = 'P2M data reset completed.'
      render :show
    end

    private

    def reset_target
      results = DataReset.new.reset_target(params.require(:target))
      errors = results.select { |result| result.fetch('error') }
      status = errors.empty? ? :ok : :unprocessable_content
      render json: { results: results, message: reset_message(errors) }, status: status
    rescue ArgumentError, ActionController::ParameterMissing => e
      render json: { message: e.message }, status: :unprocessable_content
    end

    def reset_message(errors)
      return 'Reset target removed.' if errors.empty?

      errors.flat_map { |result| result.fetch('items') }.join('; ')
    end

    def prepare_results
      @file_results, database_results = @results.partition do |result|
        !result.fetch('target').start_with?('GSABSS.')
      end
      @database_result = combined_database_result(database_results) if database_results.any?
    end

    def combined_database_result(results)
      {
        'target' => 'GSABSS database tables',
        'action' => results.any? { |result| result.fetch('error') } ? 'Completed with errors' : 'Rows removed',
        'count' => results.sum { |result| result.fetch('count') },
        'items' => results.map do |result|
          "#{result.fetch('target')}: #{result.fetch('items').join(', ')}"
        end
      }
    end
  end
end
