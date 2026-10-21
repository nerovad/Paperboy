# frozen_string_literal: true

module Aim
  # The approval stamp (decided 2026-09-25, built 2026-09-28): written when
  # an invoice is approved, to a derived copy beside the store's PDF, which
  # stays as received. Fiscal and the review page show the stamped copy once
  # it is there.
  #
  # What it says and where is the invoice's agency group's stamp layout
  # (Aim::StampLayout, #221): one or more stamp areas filled from
  # Aim::StampFields. With none saved it is the stamp v1 AIM wrote, bottom
  # right of every page:
  #
  #   06/24/2025- Invoice Date:20250616
  #   Martinez, Mark_06/27/2025_12:27:03
  module ApprovalStamp
    WARNINGS = {
      shrunk: 'text made smaller to fit',
      moved_inside: 'moved back inside the page',
      too_big: 'too big for the page even at the smallest size'
    }.freeze

    module_function

    def path(invoice) = File.join(invoice.store_dir, "#{invoice.batch_id}.stamped.pdf")

    def layout_for(invoice) = Aim::StampLayout.current_for(Aim::AgencyGroups.new.for_invoice(invoice))

    # Writes the stamped copy and notes it on the Fiscal record: when, with
    # which layout, and any safety net a stamp area needed. A PDF that cannot
    # be stamped is noted there too, so it is not tried again and again;
    # Fiscal still sees the PDF as received.
    def stamp!(record)
      invoice = record.invoice
      values = Aim::StampFields.values(invoice, record)
      return record.update!(stamp_error: 'no approval in the history') if values['approver'].blank?

      layout = layout_for(invoice)
      result = write(invoice.pdf_path, path(invoice), layout.boxes(values))
      record.update!(stamped_at: Time.current, stamp_error: nil, stamp_layout_id: layout.id,
                     stamp_warnings: describe(result.warnings))
    rescue Paperboy::Pdf::Unwritable, SystemCallError => e
      record.update!(stamped_at: nil, stamp_error: e.message.to_s.truncate(500))
    end

    # The stamped PDF +layout+ would make of +invoice+, and its warnings,
    # without writing anything (the designer's check, #221).
    def preview(invoice, layout, values: Aim::StampFields.values(invoice))
      boxes = layout.boxes(values)
      Paperboy::Pdf::Stamp.new(invoice.pdf_path).render { boxes }
    end

    # "page 1: text made smaller to fit; page 2: ...", or nil.
    def describe(warnings)
      return if warnings.blank?

      warnings.map { |page, list| "page #{page}: #{list.map { |key| WARNINGS.fetch(key, key.to_s) }.join(', ')}" }
              .join('; ').truncate(500)
    end

    # Written beside the target and renamed into place, so nobody is ever
    # served half a file.
    def write(source, target, boxes)
      temporary = "#{target}.part"
      result = Paperboy::Pdf::Stamp.new(source).write(temporary) { boxes }
      File.rename(temporary, target)
      result
    ensure
      FileUtils.rm_f(temporary) if temporary && File.exist?(temporary)
    end
  end
end
