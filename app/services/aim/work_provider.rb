# frozen_string_literal: true

module Aim
  # AIM's work, as Paperboy's inbox sees it. Reads rows: an invoice in a queue
  # a person works is an item, claimed or not. AIM v2.
  class WorkProvider < Pfa::Work::Provider
    def inbox_items(viewer:, filters: {})
      return [] unless aim_access?(viewer)

      items(filters).select do |item|
        claimed_by = item.metadata[:claimed_by]
        claimed_by.blank? || claimed_by.to_s.casecmp?(viewer[:email].to_s)
      end
    end

    def records(viewer:, filters: {})
      aim_access?(viewer) ? items(filters) : []
    end

    private

    def aim_access?(viewer)
      Array(viewer[:applications]).map(&:to_s).include?('aim')
    end

    def items(filters)
      queues(filters).flat_map do |queue|
        Aim::Invoice.in_queue(queue).newest_first.map { |invoice| item_for(queue, invoice) }
      end
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.warn("AIM work is unavailable: #{e.message}")
      []
    end

    def queues(filters)
      requested = filters[:queue].presence&.to_s
      requested && Aim::Invoice::WORK_QUEUES.include?(requested) ? [requested] : Aim::Invoice::WORK_QUEUES
    end

    def item_for(queue, invoice)
      Pfa::Work::Item.new(
        key: "aim:invoice:#{queue}:#{invoice.batch_id}",
        application: :aim,
        source_type: 'Aim::Invoice',
        source_id: invoice.batch_id,
        reference: invoice.invoice_number.presence || invoice.batch_id,
        title: Aim::Invoice::QUEUES.dig(queue, :label) || queue.humanize,
        assignee_employee_id: invoice.claimed_by,
        status: invoice.state,
        status_category: queue == 'ready_for_approval' ? :in_review : :pending,
        created_at: invoice.created_at,
        updated_at: invoice.updated_at,
        path: "/aim/invoices/#{ERB::Util.url_encode(invoice.batch_id)}?queue=#{queue}",
        actions: invoice.claimed_by.present? ? %i[open release] : %i[open claim],
        metadata: { queue: queue, claimed_by: invoice.claimed_by, vendor_name: invoice.vendor_name,
                    budget_unit: invoice.budget_unit, assigned_to: invoice.assigned_to },
        source: invoice
      )
    end
  end
end
