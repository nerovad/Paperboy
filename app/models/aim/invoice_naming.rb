# frozen_string_literal: true

module Aim
  # How an invoice is named and where its file is. Included by Aim::Invoice.
  module InvoiceNaming
    extend ActiveSupport::Concern

    # "AIM-1234": the short public number people and the Fiscal report use
    # (Joshua, 2026-09-28); the batch id stays the store's and billing's key.
    def handle = id && "AIM-#{id}"

    # The invoice's folder in the store, as this server sees it, and its PDF.
    def store_dir = File.join(Aim::InvoiceDirectoryService.instance.store_dir, batch_id)

    def pdf_path = File.join(store_dir, "#{batch_id}.pdf")
  end
end
