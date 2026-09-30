# frozen_string_literal: true

module Aim
  # An invoice's PDF in the store, for the review page and the Fiscal page:
  # the approval-stamped copy once there is one, else the PDF as received.
  # Nothing from the row may name a file outside the store: the batch id has
  # to be one path component, and the path, symlinks followed, has to stay
  # under the store.
  module StoredPdf
    extend ActiveSupport::Concern

    private

    def stored_pdf_path(invoice = @invoice)
      stamped = Aim::FiscalRecord::APPROVED_STATES.include?(invoice.state) && store_file(invoice, 'stamped.pdf')
      stamped || store_file(invoice, 'pdf')
    end

    # The store is read through Paperboy::FileStore, which refuses a name that
    # is absolute or climbs out with "..", and the file found is then resolved
    # through any symlink and has to still be in the store (DamStoragePaths'
    # check, which the DAM uses for its own roots).
    def store_file(invoice, extension)
      name = invoice.batch_id.to_s
      return if name.blank? || name.match?(%r{[/\\]}) || name.start_with?('.')

      store = Paperboy::FileStore::Local.new(Aim::InvoiceDirectoryService.instance.store_dir)
      relative = "#{name}/#{name}.#{extension}"
      return unless store.exist?(relative)

      path = Dam::StorageLocation.resolve_path(store.download(relative))
      path if Dam::StorageLocation.inside?(path, Dam::StorageLocation.resolve_path(store.path))
    rescue Aim::MissingConfiguration, ArgumentError
      nil
    end
  end
end
