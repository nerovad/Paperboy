# frozen_string_literal: true

module Aim
  module InvoicesHelper
    FIELD_LABELS = {
      'BU' => 'Business Unit',
      'BudgetUnit' => 'Business Unit',
      'Submitter' => 'Submitter',
      'VendorName' => 'Vendor Name',
      'NormalizedVendor' => 'Normalized Vendor',
      'InvoiceTotal' => 'Invoice Total',
      'InvoiceNumber' => 'Invoice Number',
      'InvoiceDate' => 'Invoice Date',
      'bu_number' => 'Business Unit',
      'submitter_name' => 'Submitter',
      'processing_id' => 'Processing ID'
    }.freeze

    # Vendor Review owns the vendor name itself: the AI-extracted value is shown
    # read-only and the official name comes from its own select. These keys are
    # pipeline plumbing or AI output that staff should never retype, so they are
    # never rendered as editable inputs and never accepted back from the form.
    VENDOR_REVIEW_PROTECTED_FIELDS = %w[
      VendorName
      ExtractedVendorName
      extracted_vendor_name
      ExtractedMetadata
      Status
      ErrorMessage
      InvoiceConcatID
    ].freeze

    # NormalizedVendor stays writable, but it is rendered by its own select
    # rather than by the generic metadata grid.
    VENDOR_REVIEW_HIDDEN_FIELDS = (VENDOR_REVIEW_PROTECTED_FIELDS + %w[NormalizedVendor]).freeze

    def aim_vendor_review_hidden_fields
      VENDOR_REVIEW_HIDDEN_FIELDS
    end

    def aim_queue_label(queue)
      Aim::InvoiceDirectoryService::BACKEND_QUEUES.dig(queue.to_s.to_sym, :label) ||
        queue.to_s.tr('_', ' ').titleize
    end

    def aim_queue_description(queue)
      Aim::InvoiceDirectoryService::BACKEND_QUEUES.dig(queue.to_s.to_sym, :description)
    end

    def aim_metadata_label(key)
      FIELD_LABELS.fetch(key.to_s, key.to_s.underscore.humanize.titleize)
    end

    def aim_metadata_value(metadata, *keys)
      keys.each do |key|
        value = metadata[key.to_s]
        return value if value.present?
      end

      nil
    end

    # Invoices reach these queues because extraction went sideways, so an
    # invoice number is often missing. Report that honestly — the folder's
    # "…-[3SZK]" code is not an invoice number and must never stand in for one.
    def aim_invoice_reference(invoice)
      aim_metadata_value(invoice[:metadata], 'InvoiceNumber', 'invoice_number', 'Invoice Number')
    end

    # Totals and dates arrive as free-form metadata strings. Format the ones
    # that really are numbers or dates and pass anything else through untouched
    # so partial extractions still render whatever the AI produced.
    def aim_currency(value)
      return value if value.blank?

      numeric = value.to_s.delete('$,').strip
      return value unless numeric.match?(/\A-?\d+(\.\d+)?\z/)

      number_to_currency(numeric.to_d)
    end

    # Vendors print dates however they like. Numeric ones are read month-first
    # because these are US invoices — Date.parse would take 8/12/2026 as the
    # eighth of December. Anything unparseable renders as extracted.
    US_NUMERIC_DATE_PATTERN = %r{\A(\d{1,2})[/-](\d{1,2})[/-](\d{2}|\d{4})\z}

    def aim_invoice_date(value)
      return value if value.blank?

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
    # display name alongside it. Claims written before the name was recorded
    # fall back to a readable mailbox rather than showing an address.
    def aim_claimant_label(invoice)
      return invoice[:claimed_by_name] if invoice[:claimed_by_name].present?

      mailbox = invoice[:claimed_by].to_s.split('@').first
      return 'Someone' if mailbox.blank?

      mailbox.tr('._-', ' ').squish.titleize
    end

    def aim_status_badge(invoice, current_user)
      return [invoice[:status_badge], invoice[:status_text]] if invoice[:status_badge].present?
      return ['is-in-review', 'Claimed by You'] if invoice[:claimed_by] == current_user
      return ['is-in-review', "Claimed by #{aim_claimant_label(invoice)}"] if invoice[:claimed_by].present?

      ['is-approved', invoice[:metadata]['Status'].presence || 'Ready']
    end
  end
end
