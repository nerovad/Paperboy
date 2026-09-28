# frozen_string_literal: true

module Aim
  # The approval stamp (decided 2026-09-25, built 2026-09-28): on every page,
  # bottom right, as v1 AIM did --
  #
  #   06/24/2025- Invoice Date:20250616
  #   Martinez, Mark_06/27/2025_12:27:03
  #
  # the date AIM received the invoice and its invoice date, then who approved
  # it and when. Written to a derived copy beside the store's PDF, which stays
  # as received. Fiscal and the review page show the stamped copy once it is
  # there.
  module ApprovalStamp
    module_function

    def lines(invoice)
      approved = Aim::FiscalExport.approval_stamps([invoice.id])[invoice.id]
      return if approved.nil?

      ["#{invoice.created_at.in_time_zone.strftime('%m/%d/%Y')}- Invoice Date:#{invoice.invoice_date&.strftime('%Y%m%d')}",
       approved]
    end

    def path(invoice) = File.join(invoice.store_dir, "#{invoice.batch_id}.stamped.pdf")

    # Writes the stamped copy and notes it on the Fiscal record. A PDF that
    # cannot be stamped is noted there too, so it is not tried again and
    # again; Fiscal still sees the PDF as received.
    def stamp!(record)
      invoice = record.invoice
      text = lines(invoice)
      return record.update!(stamp_error: 'no approval in the history') if text.nil?

      write(invoice.pdf_path, path(invoice), text)
      record.update!(stamped_at: Time.current, stamp_error: nil)
    rescue Aim::PdfStamp::Unstampable, SystemCallError => e
      record.update!(stamped_at: nil, stamp_error: e.message.to_s.truncate(500))
    end

    # Written beside the target and renamed into place, so nobody is ever
    # served half a file.
    def write(source, target, text)
      temporary = "#{target}.part"
      Aim::PdfStamp.new(source).write(temporary, text)
      File.rename(temporary, target)
    ensure
      FileUtils.rm_f(temporary) if temporary && File.exist?(temporary)
    end
  end
end
