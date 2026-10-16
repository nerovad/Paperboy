# frozen_string_literal: true

module Aim
  module InvoicesHelper
    FIELD_LABELS = {
      'document_type' => 'Document Type',
      'vendor_name' => 'Vendor Name',
      'extracted_vendor_name' => 'AI-Extracted Vendor',
      'invoice_number' => 'Invoice Number',
      'invoice_date' => 'Invoice Date',
      'invoice_total' => 'Invoice Total',
      'subtotal' => 'Subtotal',
      'sales_tax' => 'Sales Tax',
      'order_number' => 'Order Number',
      'customer_number' => 'Customer Number',
      'budget_unit' => 'Budget Unit',
      'submitter' => 'Submitter',
      'notes' => 'Notes'
    }.freeze

    REVIEW_REASON_LABELS = {
      'unknown_type' => 'Unknown document type',
      'unknown_vendor' => 'Unknown vendor',
      'missing_fields' => 'Missing fields',
      'low_confidence' => 'Low confidence read',
      'duplicate' => 'Possible duplicate',
      'sent_back' => 'Sent back',
      'handwritten' => 'Handwritten amounts',
      'extraction_error' => 'Extraction error',
      'split_error' => 'Split error',
      'export_error' => 'Export error',
      'needs_split' => 'Needs split'
    }.freeze

    # An Action Needed row's reason for the filter: its review reason, or
    # Needs split for a PDF holding several invoices.
    def aim_filter_reason(invoice) = invoice.state == 'needs_split' ? 'needs_split' : invoice.review_reason

    STATE_LABELS = {
      'received' => 'Waiting for AI',
      'extracting' => 'AI reading',
      'needs_review' => 'Needs review',
      'needs_split' => 'Needs split',
      'ready_for_approval' => 'Ready for approval',
      'approved' => 'Approved',
      'exporting' => 'Exporting',
      'exported' => 'Exported',
      'failed' => 'Failed',
      'rejected' => 'Rejected',
      'deleted' => 'Deleted',
      'split' => 'Split'
    }.freeze

    def aim_queue_label(queue)
      Aim::Invoice::QUEUES.dig(queue.to_s, :label) || queue.to_s.tr('_', ' ').titleize
    end

    def aim_queue_description(queue)
      Aim::Invoice::QUEUES.dig(queue.to_s, :description)
    end

    def aim_field_label(key)
      FIELD_LABELS.fetch(key.to_s, key.to_s.humanize)
    end

    def aim_review_reason_label(reason)
      REVIEW_REASON_LABELS.fetch(reason.to_s, reason.to_s.humanize)
    end

    def aim_state_label(state)
      STATE_LABELS.fetch(state.to_s, state.to_s.humanize)
    end

    # Who sent an invoice back, and when (#160): the move that did it, from
    # its history. Nil if the history has no such move.
    def aim_sent_back_by(invoice)
      event = invoice.events.where(to_state: 'needs_review').order(:id).last
      return if event.nil?

      mailbox = event.actor.to_s.split('@').first.to_s
      [mailbox.tr('._-', ' ').squish.titleize.presence || 'Someone', event.created_at.in_time_zone]
    end

    # A notice on the review page (#160) is a chip in the header that drops
    # its panel down over the page: this heads the panel and records the chip
    # (aim_notice_chips) the header shows. The panel's id is aim_notice_id.
    def aim_notice_heading(title, mark:, tone: :alert)
      (@aim_notice_chips ||= []) << { id: aim_notice_id(title), title: title, mark: mark, tone: tone }
      content_tag(:strong, title)
    end

    def aim_notice_id(title) = "aim-notice-#{title.to_s.parameterize}"

    def aim_notice_chips = @aim_notice_chips || []

    # A notice's title as its fold toggle (aim_banner_controller, #160): the
    # caret and "Expand" are rendered here, and the notice is rendered folded
    # (is-folded), so nothing moves once the page has loaded.
    def aim_notice_title(text, element: :strong)
      content_tag(element, class: 'aim-readonly-banner__toggle', role: 'button', tabindex: 0, aria: { expanded: false },
                       data: { action: 'click->aim-banner#toggle keydown->aim-banner#key' }) do
        safe_join([text, tag.span(class: 'aim-readonly-banner__caret', aria: { hidden: true }),
                   tag.span('Expand', class: 'aim-readonly-banner__hint')])
      end
    end

    # A possible duplicate beside its original (#160): [label, this, original,
    # differs?] per row, differs? comparing the values shown.
    def aim_duplicate_comparison(invoice, other)
      rows = [
        ['Vendor', invoice.vendor_name, other.vendor_name],
        ['Invoice #', invoice.invoice_number, other.invoice_number],
        ['Invoice date', aim_invoice_date(invoice.invoice_date), aim_invoice_date(other.invoice_date)],
        ['Total', aim_currency(invoice.invoice_total), aim_currency(other.invoice_total)],
        ['Budget unit', invoice.budget_unit, other.budget_unit],
        ['Order #', invoice.order_number, other.order_number],
        ['Customer #', invoice.customer_number, other.customer_number],
        ['Submitter', invoice.submitter, other.submitter],
        ['Pages', invoice.page_count, other.page_count]
      ]
      rows.map { |label, mine, theirs| [label, mine.presence || '—', theirs.presence || '—', mine.to_s.squish != theirs.to_s.squish] }
    end

    # Totals arrive typed now, but a reviewer may have typed "$1,234.50" into
    # the box, so this still accepts a string and passes anything else through.
    def aim_currency(value)
      return value if value.blank?
      return number_to_currency(value) if value.is_a?(Numeric)

      numeric = value.to_s.delete('$,').strip
      return value unless numeric.match?(/\A-?\d+(\.\d+)?\z/)

      number_to_currency(numeric.to_d)
    end

    # Vendors print dates however they like. Numeric ones are read month-first
    # because these are US invoices -- Date.parse would take 8/12/2026 as the
    # eighth of December. Anything unparseable renders as extracted.
    US_NUMERIC_DATE_PATTERN = %r{\A(\d{1,2})[/-](\d{1,2})[/-](\d{2}|\d{4})\z}

    def aim_invoice_date(value)
      return value if value.blank?
      return value.strftime('%m/%d/%y') if value.respond_to?(:strftime)

      parsed = aim_parsed_invoice_date(value.to_s.strip)
      parsed ? parsed.strftime('%m/%d/%y') : value
    end

    def aim_parsed_invoice_date(value)
      match = US_NUMERIC_DATE_PATTERN.match(value)
      return Date.new(aim_expanded_year(match[3]), match[1].to_i, match[2].to_i) if match

      Date.parse(value)
    rescue Date::Error, TypeError
      nil
    end

    def aim_expanded_year(year)
      year.length == 2 ? year.to_i + 2000 : year.to_i
    end

    # A claim records the claimant's email as its identity key and their
    # display name alongside it. Claims without a name fall back to a readable
    # mailbox rather than showing an address.
    def aim_claimant_label(invoice)
      return invoice.claimed_by_name if invoice.claimed_by_name.present?

      mailbox = invoice.claimed_by.to_s.split('@').first
      return 'Someone' if mailbox.blank?

      mailbox.tr('._-', ' ').squish.titleize
    end

    # [badge class, text] for a queue row, classed as submissions are
    # (SubmissionsHelper#category_badge_class).
    def aim_status_badge(invoice, current_user_email)
      category, text =
        if invoice.held_by?(current_user_email) then [:in_review, 'Open by you']
        elsif invoice.claimed_by_other?(current_user_email) then [:in_review, "Open by #{aim_claimant_label(invoice)}"]
        elsif invoice.review_reason.present? then [:denied, aim_review_reason_label(invoice.review_reason)]
        else [:approved, aim_state_label(invoice.state)]
        end
      [category_badge_class(category), text]
    end

    # A queue owner for a heading or a notice.
    def aim_owner_label(owner)
      owner.to_s == Aim::Invoice::SHARED_QUEUE ? 'the shared queue' : "#{owner}'s queue"
    end
  end
end
