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
      too_big: 'too big for the page even at the smallest size',
      covers_text: 'sits over text on the page'
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
      result = write(invoice.pdf_path, path(invoice), layout.boxes(values), shrink: layout.shrink)
      record.update!(stamped_at: Time.current, stamp_error: nil, stamp_layout_id: layout.id,
                     stamp_warnings: describe(result.warnings))
    rescue Paperboy::Pdf::Unwritable, SystemCallError => e
      record.update!(stamped_at: nil, stamp_error: e.message.to_s.truncate(500))
    end

    # The stamped PDF +layout+ would make of the PDF at +source+ filled with
    # +values+, and its warnings, without writing anything (the designer's
    # check, #221). With
    # +check_overlap+, an area sitting over the page's own text is a warning.
    def preview(layout, source:, values:, check_overlap: false)
      boxes = layout.boxes(values)
      Paperboy::Pdf::Stamp.new(source).render(check_overlap: check_overlap, shrink: layout.shrink) { boxes }
    end

    # "moved back inside the page (pages 1-51); text made smaller to fit
    # (page 3)", or nil: each safety net once, with the pages it was needed on.
    def describe(warnings)
      return if warnings.blank?

      pages = Hash.new { |hash, key| hash[key] = [] }
      warnings.each { |page, list| list.each { |key| pages[key] << page } }
      pages.map { |key, list| "#{WARNINGS.fetch(key, key.to_s)} (#{page_ranges(list)})" }.join('; ').truncate(500)
    end

    # [1, 2, 3, 5] -> "pages 1-3, 5"; [4] -> "page 4".
    def page_ranges(pages)
      runs = pages.sort.uniq.slice_when { |a, b| b != a + 1 }.map { |run| run.size > 1 ? "#{run.first}-#{run.last}" : run.first.to_s }
      "#{pages.uniq.size == 1 ? 'page' : 'pages'} #{runs.join(', ')}"
    end

    # Written beside the target and renamed into place, so nobody is ever
    # served half a file.
    def write(source, target, boxes, shrink: nil)
      temporary = "#{target}.part"
      result = Paperboy::Pdf::Stamp.new(source).write(temporary, shrink: shrink) { boxes }
      File.rename(temporary, target)
      result
    ensure
      FileUtils.rm_f(temporary) if temporary && File.exist?(temporary)
    end
  end
end
