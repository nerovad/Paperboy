# frozen_string_literal: true

module Aim
  # Straight to Fiscal, read by the AI (#131): once the AI (or AIM staff, after
  # Action Needed) has an invoice ready for approval, it is approved in the
  # uploader's name and goes on to export and Fiscal, with no person's queue
  # in between. Every minute (config/recurring.yml).
  class StraightToFiscalJob < ApplicationJob
    queue_as :default

    def perform
      Aim::Invoice.where(state: 'ready_for_approval').where.not(straight_to_fiscal_by: nil).find_each do |invoice|
        next unless invoice.ready_for_a_user?

        invoice.request_export!(actor: invoice.straight_to_fiscal_by, note: 'straight to Fiscal: approved by its uploader')
        Aim::StampApprovedJob.perform_later(invoice.id)
      rescue Aim::Invoice::IllegalTransition, ActiveRecord::RecordInvalid => e
        Rails.logger.warn "AIM could not send #{invoice.batch_id} straight to Fiscal: #{e.message}"
      end
    end
  end
end
