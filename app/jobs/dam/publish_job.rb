# frozen_string_literal: true

module Dam
  # Sends one asset to one publish target, away from the request that asked
  # for it — a video upload takes as long as the file and the uplink take.
  #
  # No retry_on: Dam::Publishing::Runner records a failure on the publication
  # and stops. Publishing twice because a worker retried would put the video
  # up twice, and the retry button on the publication page makes a new row on
  # purpose so both attempts stay visible.
  class PublishJob < ApplicationJob
    queue_as :default

    discard_on ActiveRecord::RecordNotFound

    def perform(publication_id)
      Dam::Publishing::Runner.new(Dam::Publication.find(publication_id)).call
    end
  end
end
