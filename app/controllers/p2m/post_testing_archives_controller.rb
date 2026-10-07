# frozen_string_literal: true

module P2m
  class PostTestingArchivesController < ApplicationController
    before_action -> { require_app_feature('p2m', 'data_reset', fallback: p2m_root_path) }

    def show
      @jobs = PostTestingArchive.new.preview
    rescue StandardError => e
      @jobs = []
      flash.now[:alert] = "Historical search failed: #{e.message}"
    end

    def create
      result = PostTestingArchive.new.move(params.require(:oms_number))
      status = result.fetch('error') ? :unprocessable_content : :ok
      render json: { result: result, message: result.fetch('message') }, status: status
    rescue ArgumentError, ActionController::ParameterMissing, SystemCallError => e
      render json: { message: e.message }, status: :unprocessable_content
    end
  end
end
