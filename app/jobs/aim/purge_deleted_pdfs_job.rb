# frozen_string_literal: true

module Aim
  # Purges the PDFs of invoices deleted longer ago than the retention period
  # (#170), every night (config/recurring.yml); nothing unless
  # AIM_PURGE_DELETED_PDFS=on. See Aim::DeletedPdfPurge.
  class PurgeDeletedPdfsJob < ApplicationJob
    queue_as :default

    def perform
      return unless Aim::DeletedPdfPurge.enabled?

      purged = Aim::DeletedPdfPurge.new.run
      Rails.logger.info "AIM purged the PDFs of #{purged} deleted invoice(s)" if purged.positive?
    end
  end
end
