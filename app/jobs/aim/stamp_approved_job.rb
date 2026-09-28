# frozen_string_literal: true

module Aim
  # Stamps approved invoices (Aim::ApprovalStamp). Queued for one invoice when
  # it is approved or Fiscal changes it; run every ten minutes over every
  # approved invoice not yet stamped (config/recurring.yml), which also
  # stamps those approved before the stamp existed. One that failed is left
  # until something queues it by name.
  class StampApprovedJob < ApplicationJob
    queue_as :default

    def perform(invoice_id = nil)
      return stamp_one(invoice_id) if invoice_id

      Aim::FiscalRecord.take_in_approved!
      Aim::FiscalRecord.includes(:invoice).where(stamped_at: nil, stamp_error: nil).find_each do |record|
        Aim::ApprovalStamp.stamp!(record)
      end
    end

    private

    def stamp_one(invoice_id)
      invoice = Aim::Invoice.find_by(id: invoice_id)
      return unless invoice && Aim::FiscalRecord::APPROVED_STATES.include?(invoice.state)

      record = Aim::FiscalRecord.find_or_create_by!(invoice_id: invoice.id)
      Aim::ApprovalStamp.stamp!(record)
    end
  end
end
