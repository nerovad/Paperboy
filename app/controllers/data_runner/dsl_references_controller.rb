# frozen_string_literal: true

module DataRunner
  class DslReferencesController < ApplicationController
    before_action :require_login

    def show
      @dsl = DslCatalog.find!(params[:name])
      @reference_path = @dsl.sop&.fetch(:reference_path, nil)
      raise ActiveRecord::RecordNotFound if @reference_path.blank?

      @reference_entries = DirectoryListing.new(@reference_path).call
      render :show, layout: false
    rescue DirectoryListing::Unavailable => e
      @reference_error = e.message
      render :show, layout: false, status: :service_unavailable
    end
  end
end
