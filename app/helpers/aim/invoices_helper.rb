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
      'handwritten' => 'Handwritten amounts',
      'extraction_error' => 'Extraction error',
      'split_error' => 'Split error',
      'export_error' => 'Export error'
    }.freeze

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

    def aim_status_badge(invoice, current_user_email)
      return ['is-in-review', 'Claimed by You'] if invoice.held_by?(current_user_email)
      return ['is-in-review', "Claimed by #{aim_claimant_label(invoice)}"] if invoice.claimed_by.present?
      return ['is-denied', aim_review_reason_label(invoice.review_reason)] if invoice.review_reason.present?

      ['is-approved', aim_state_label(invoice.state)]
    end
  end
end
