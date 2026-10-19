# frozen_string_literal: true

module Aim
  # Purges the PDFs of invoices deleted longer ago than the retention period
  # (#170): the stored PDF, its approval-stamped copy and the deleted folder's
  # copy. The row stays as the record -- batch id, vendor, number, total, who
  # deleted it and why, its history -- with pdf_purged_at and a history line,
  # and the duplicate check still sees it. Rejected invoices are never purged.
  #
  # Off until AIM_PURGE_DELETED_PDFS=on: the period (AIM_DELETED_PDF_RETENTION_DAYS,
  # 90 unless set) waits on Fiscal or the records officer. A second run, or a
  # run after a crash, purges only invoices not yet marked; a file already
  # gone is not an error.
  class DeletedPdfPurge
    DEFAULT_RETENTION_DAYS = 90
    ACTOR = 'aim'

    def self.enabled? = ENV.fetch('AIM_PURGE_DELETED_PDFS', '').casecmp?('on')

    def self.retention_days
      days = ENV.fetch('AIM_DELETED_PDF_RETENTION_DAYS', '').to_i
      days.positive? ? days : DEFAULT_RETENTION_DAYS
    end

    def initialize(now: Time.current, directories: Aim::InvoiceDirectoryService.instance)
      @now = now
      @directories = directories
    end

    # Deleted, not yet purged, and deleted before the period began. Dated by
    # finished_at, else (deleted before #169 dated it) the last change.
    def due
      cutoff = @now - self.class.retention_days.days
      Aim::Invoice.where(state: 'deleted', pdf_purged_at: nil)
                  .where('COALESCE(finished_at, updated_at) < ?', cutoff)
    end

    # Purges every invoice due; returns how many.
    def run = due.find_each.count { |invoice| purge(invoice) }

    # Removes +invoice+'s PDFs and marks it; returns how many files it
    # removed. Nil, with nothing changed, for an invoice that is not deleted,
    # is already purged, or has a batch id that is not one plain folder name.
    def purge(invoice)
      return unless invoice.state == 'deleted' && invoice.pdf_purged_at.nil? && plain?(invoice.batch_id)

      removed = files(invoice).select { |path| File.file?(path) }.each { |path| FileUtils.rm_f(path) }
      remove_empty_folder(File.join(@directories.deleted_dir, invoice.batch_id))
      invoice.transaction do
        invoice.update_columns(pdf_purged_at: @now)
        invoice.events.create!(action: 'pdf_purged', actor: ACTOR,
                               note: "PDF purged after #{self.class.retention_days} days in Deleted " \
                                     "(#{removed.empty? ? 'no file was left' : "#{removed.size} file#{'s' unless removed.size == 1} removed"})")
      end
      removed.size
    end

    private

    def files(invoice)
      id = invoice.batch_id
      store = File.join(@directories.store_dir, id)
      [File.join(store, "#{id}.pdf"), File.join(store, "#{id}.stamped.pdf"), File.join(@directories.deleted_dir, id, "#{id}.pdf")]
    end

    def plain?(id) = id.present? && !id.match?(%r{[/\\]}) && !id.start_with?('.')

    def remove_empty_folder(folder)
      Dir.rmdir(folder) if Dir.exist?(folder) && Dir.empty?(folder)
    end
  end
end
