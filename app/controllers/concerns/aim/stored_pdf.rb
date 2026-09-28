# frozen_string_literal: true

module Aim
  # An invoice's PDF in the store, for the review page and the Fiscal page:
  # the approval-stamped copy once there is one, else the PDF as received.
  # Nothing from the row may name a file outside the store: the batch id has
  # to be one path component, and the resolved path has to stay under the
  # store.
  module StoredPdf
    extend ActiveSupport::Concern

    private

    def stored_pdf_path(invoice = @invoice)
      stamped = Aim::FiscalRecord::APPROVED_STATES.include?(invoice.state) && store_file(invoice, 'stamped.pdf')
      stamped || store_file(invoice, 'pdf')
    end

    def store_file(invoice, extension)
      store = File.expand_path(Aim::InvoiceDirectoryService.instance.store_dir)
      name = invoice.batch_id.to_s
      return if name.blank? || name.match?(%r{[/\\]}) || name.start_with?('.')

      path = File.expand_path(File.join(store, name, "#{name}.#{extension}"))
      path if path.start_with?("#{store}/") && File.file?(path)
    rescue Aim::MissingConfiguration
      nil
    end
  end
end
