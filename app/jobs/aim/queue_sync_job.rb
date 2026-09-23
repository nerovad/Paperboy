# frozen_string_literal: true

module Aim
  # Keeps the invoice rows in step with the queue folders on the share.
  #
  # The workers and the queue screens record every move they make, but a
  # folder dragged by hand, a database that was down for a minute, or a worker
  # that crashed between moving a file and writing its row all leave the two
  # apart. This is what puts them back, every ten minutes, so that when the
  # screens read rows nothing has dropped out of sight. Plan step 5.7b.
  #
  # On a host where AIM is not configured every queue is unreachable, and the
  # sync does nothing at all.
  class QueueSyncJob < ApplicationJob
    queue_as :default

    def perform
      report = Aim::QueueSync.new.call
      return if report.folder_counts.empty?

      if report.changed.positive? || report.missing.positive?
        Rails.logger.info(
          "AIM queue sync: #{report.adopted} adopted, #{report.moved} moved, " \
          "#{report.jumped} moved outside the pipeline, #{report.missing} with no folder"
        )
      end
      return if report.agreed?

      Rails.logger.warn("AIM queue sync: folders and rows still disagree: #{report.disagreements.inspect}")
    end
  end
end
