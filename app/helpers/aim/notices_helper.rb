# frozen_string_literal: true

module Aim
  # The review and Fiscal pages' notices (#160): chips in the header that drop
  # their panels down over the page, the Invoice panel's foldable note, a
  # duplicate beside its original, and the pills that say where an invoice
  # stands as a duplicate.
  module NoticesHelper
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

    DUPLICATE_PILLS = {
      possible: ['Possible duplicate', 'is-denied'], rejected: ['Rejected duplicate', 'is-denied'],
      replaced: %w[Replaced is-scheduled], replacement: %w[Replacement is-scheduled],
      known: ['Known duplicate', 'is-pending']
    }.freeze

    # A row's duplicate pill (#160), or nil. Possible duplicate is already the
    # row's reason in Action Needed, so it is not shown twice. Which invoices
    # have been replaced is looked up once per page.
    def aim_duplicate_pill(invoice)
      @aim_replaced_ids ||= Aim::Invoice.where.not(replaces_invoice_id: nil).distinct.pluck(:replaces_invoice_id).to_set
      status = invoice.duplicate_status(replaced: @aim_replaced_ids.include?(invoice.id))
      return if status.nil? || (status == :possible && invoice.state == 'needs_review')

      text, css = DUPLICATE_PILLS.fetch(status)
      content_tag(:span, text, class: "badge #{css}")
    end
  end
end
