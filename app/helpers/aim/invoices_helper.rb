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

    def aim_status_badge(invoice, current_user)
      return [invoice[:status_badge], invoice[:status_text]] if invoice[:status_badge].present?
      return ['is-in-review', 'Claimed by You'] if invoice[:claimed_by] == current_user
      return ['is-in-review', "Claimed by #{invoice[:claimed_by]}"] if invoice[:claimed_by].present?

      ['is-approved', invoice[:metadata]['Status'].presence || 'Ready']
    end
  end
end
