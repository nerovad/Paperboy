# frozen_string_literal: true

module Aim
  # An invoice's PDF in the store, for the review page and the Fiscal page.
  # Nothing from the row may name a file outside the store: the batch id has
  # to be one path component, and the resolved path has to stay under the
  # store.
  module StoredPdf
    extend ActiveSupport::Concern

    private

    def stored_pdf_path(invoice = @invoice)
      store = File.expand_path(Aim::InvoiceDirectoryService.instance.store_dir)
      name = invoice.batch_id.to_s
      return if name.blank? || name.match?(%r{[/\\]}) || name.start_with?('.')

      path = File.expand_path(File.join(store, name, "#{name}.pdf"))
      path if path.start_with?("#{store}/") && File.file?(path)
    rescue Aim::MissingConfiguration
      nil
    end
  end
end
