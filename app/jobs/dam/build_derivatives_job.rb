# frozen_string_literal: true

module Dam
  # Builds an asset's proxy and thumbnail away from the request or the scan
  # that created it, since ffmpeg and ImageMagick take as long as they take.
  #
  # discard_on ActiveRecord::RecordNotFound because an asset deleted between
  # the enqueue and the run is not an error worth retrying.
  class BuildDerivativesJob < ApplicationJob
    queue_as :default

    discard_on ActiveRecord::RecordNotFound

    def perform(asset_id)
      Dam::DerivativeBuilder.new(Dam::Asset.find(asset_id)).call
    end
  end
end
