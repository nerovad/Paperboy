# frozen_string_literal: true

module Aim
  # What the SQL worker needs from a folder a person sends it.
  #
  # The worker inserts only what a folder's *_READY_FOR_SQL.json says, and a
  # folder without one is skipped -- for ever, every five seconds, as a
  # half-built CV62744 folder was on 2026-09-24. Action Needed folders carry a
  # payload, and the review page edits it directly. Low Confidence Review
  # folders carry only the XML the AI wrote, so Send to SQL Queue used to move
  # a folder the worker could never process. Now the payload is written from
  # the reviewed fields before anything moves, the way Vendor Review already
  # builds its own, and an invoice still missing its vendor or invoice number
  # is not sent at all.
  module InvoiceSqlPayload
    extend ActiveSupport::Concern

    # What a billing row cannot do without, under each spelling the metadata
    # may use: the payload's, the XML's, and the worker's.
    REQUIRED_FOR_SQL = {
      'a vendor name' => ['VendorName', 'Vendor Name', 'vendor_name'],
      'an invoice number' => ['InvoiceNumber', 'Invoice Number', 'invoice_number']
    }.freeze

    private

    def send_to_sql_queue
      metadata = read_metadata(metadata_path_for(@folder_path))
      gaps = REQUIRED_FOR_SQL.reject { |_, keys| sql_field(metadata, keys).present? }.keys
      if gaps.any?
        return redirect_to aim_invoice_path(@invoice_id, queue: @queue),
                           alert: "This invoice still needs #{gaps.to_sentence}. Fill that in, then send it. " \
                                  'Nothing has moved.'
      end

      write_sql_payload(metadata) unless sql_payload_present?
      move_invoice_to(Aim::InvoiceDirectoryService.instance.sql_queue_dir,
                      'Invoice index verified and routed to SQL Queue.', state: 'sql_queue')
    rescue *Aim::InvoiceFileSupport::WRITE_FAILURES => e
      queue_not_writable(e)
    end

    def sql_payload_present?
      Dir.children(@folder_path).any? { |name| name.end_with?(Aim::InvoiceQueueSupport::PAYLOAD_SUFFIX) }
    end

    # Built from the fields the reviewer has just saved -- the XML, on a Low
    # Confidence Review folder -- so the billing row and the XML agree.
    def write_sql_payload(metadata)
      vendor = sql_field(metadata, REQUIRED_FOR_SQL['a vendor name'])
      payload = Aim::VendorReviewPayloadService.sql_ready_payload(
        invoice_id: @invoice_id,
        pdf_file: pdf_files_for(@folder_path).first,
        metadata: metadata,
        extracted_name: sql_field(metadata, %w[ExtractedVendorName extracted_vendor_name]) || vendor,
        normalized_name: vendor
      )
      File.write(File.join(@folder_path, "#{@invoice_id}#{Aim::InvoiceQueueSupport::PAYLOAD_SUFFIX}"),
                 JSON.pretty_generate(payload))
    end

    def sql_field(metadata, keys)
      keys.map { |key| metadata[key] }.find(&:present?)&.to_s&.strip
    end
  end
end
