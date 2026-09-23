# frozen_string_literal: true

module Aim
  # Which invoices a queue screen lists. Plan step 5.7b.
  #
  # The rows say which invoices are in a queue; the folder under each is
  # where its files are. Three rules keep that from losing anything:
  #
  # * **Every row in this state is listed**, even one whose folder has gone
  #   missing -- flagged, so someone looks, rather than silently absent.
  # * **A folder with no row is listed too**, flagged "Not yet recorded". The
  #   scheduled sync adopts it within minutes; until then it must not vanish
  #   from the one screen people use to find work.
  # * **What each line shows is the folder's metadata first** -- the JSON a
  #   reviewer edits -- with the row filling what it lacks. Editing moves onto
  #   the row in Phase 9; showing the row first before then would show a value
  #   a reviewer has already corrected.
  #
  # If the rows cannot be read at all, the list falls back to the folders and
  # the screen says so: the folders are still enough to work from.
  module InvoiceQueueListing
    extend ActiveSupport::Concern

    private

    def load_invoices
      folders = queue_folders
      rows = recorded_invoices
      return list_folders_only(folders) if rows.nil?

      @claim_rows = rows

      (rows.keys | folders.keys).each do |batch_id|
        @invoices << listed_invoice(batch_id, folders[batch_id], rows[batch_id])
      end
    end

    def list_folders_only(folders)
      @rows_unavailable = true
      folders.each_value { |folder| @invoices << invoice_summary(folder) }
    end

    def recorded_invoices
      Aim::Invoice.where(state: @queue).index_by(&:batch_id)
    rescue StandardError => e
      Rails.logger.warn "AIM #{@queue} queue listed from its folders; the invoice rows are unavailable: #{e.message}"
      nil
    end

    # batch id => folder. A rejected invoice sits one level down, under the
    # <Submitter>_<BU> group Rails files it in; the group is not an invoice.
    def queue_folders
      pattern = @queue == 'rejected' ? File.join(@base_path.to_s, '*', '*') : File.join(@base_path.to_s, '*')
      Dir.glob(pattern).select { |path| File.directory?(path) }.to_h { |path| [File.basename(path), path] }
    end

    def listed_invoice(batch_id, folder, row)
      summary = folder ? invoice_summary(folder) : files_missing_summary(batch_id)
      # Flagged beside the status rather than in place of it: who is holding
      # an invoice matters more than whether its row has caught up.
      summary[:recorded] = row.present?
      return summary if row.nil?

      summary[:metadata] = row_metadata(row).merge(summary[:metadata].compact_blank)
      summary
    end

    def files_missing_summary(batch_id)
      { id: batch_id, name: batch_id, path: nil, metadata: {}, pdf_file: nil,
        status_text: 'Files not found on the share', status_badge: 'is-denied',
        reviewable: false, claimed_by: nil, claimed_by_name: nil, is_locked: false }
    end

    # The row's facts under the names the queue screens already read, for
    # the folder's metadata to override.
    def row_metadata(row)
      {
        'VendorName' => row.vendor_name.presence || row.extracted_vendor_name,
        'InvoiceNumber' => row.invoice_number,
        'BU' => row.budget_unit,
        'Submitter' => row.submitter,
        'InvoiceDate' => row.invoice_date&.iso8601,
        'InvoiceTotal' => row.invoice_total&.to_s('F'),
        'DocumentType' => row.document_type,
        'bu_number' => row.budget_unit,
        'submitter_name' => row.submitter,
        'processing_id' => row.batch_id
      }.compact_blank
    end
  end
end
