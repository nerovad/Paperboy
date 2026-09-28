# frozen_string_literal: true

module P2m
  class SearchesController < ApplicationController
    def cancel
      Paperboy::SearchCancellation.cancel!(params.require(:token))
      head :no_content
    rescue ArgumentError, ActionController::ParameterMissing => e
      render json: { message: e.message }, status: :unprocessable_content
    end
  end
end
