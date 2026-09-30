# frozen_string_literal: true

module Aim
  # AIM's work, as Paperboy's inbox sees it. Reads rows: an invoice in a queue
  # a person works is an item, claimed or not. AIM v2.
  #
  # A person's inbox holds what their own AIM queues hold, scoped as AIM
  # scopes them (Aim::InvoiceAssignment): My Queue (ready invoices they own)
  # and Shared Queues (unowned ready invoices in the BUs whose shared queue
  # they pick up from). AIM Admins also work Action Needed and Failed, the
  # Pipeline's queues. Nothing someone else has open is listed. #records, the
  # whole of AIM's open work, is unchanged.
  class WorkProvider < Pfa::Work::Provider
    # The most rows one queue puts in an inbox; AIM's own screens list the rest.
    INBOX_LIMIT = 200

    def inbox_items(viewer:, filters: {})
      return [] unless aim_access?(viewer)

      employee_id = viewer[:employee_id].presence
      return [] if employee_id.nil?

      items = inbox_scopes(employee_id, filters).flat_map do |queue, scope|
        scope.newest_first.limit(INBOX_LIMIT).map { |invoice| item_for(queue, invoice) }
      end
      items.reject { |item| claimed_by_other?(item, viewer) }.uniq(&:key)
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.warn("AIM work is unavailable: #{e.message}")
      []
    end

    def records(viewer:, filters: {})
      aim_access?(viewer) ? items(filters) : []
    end

    private

    # [queue, relation] for each queue of the viewer's that the filters ask for.
    def inbox_scopes(employee_id, filters)
      ready = 'ready_for_approval'
      scopes = [[ready, Aim::Invoice.owned_by(employee_id).in_queue(ready)],
                [ready, Aim::Invoice.shared_for(Aim::Users.shared_budget_units(employee_id, staff: false))]]
      scopes += (Aim::Invoice::WORK_QUEUES - [ready]).map { |queue| [queue, Aim::Invoice.in_queue(queue)] } if aim_admin?(employee_id)
      requested = queues(filters)
      scopes.select { |pair| requested.include?(pair.first) }
    end

    # AIM Admins: the aim_admin group, and system admins (Aim::Users#role_names).
    def aim_admin?(employee_id)
      Group.employee_ids_named(Group::PRIVILEGED_NAME, *Aim::Users::GROUPS).map(&:to_s).include?(employee_id.to_s)
    end

    def claimed_by_other?(item, viewer)
      claimed_by = item.metadata[:claimed_by]
      claimed_by.present? && !claimed_by.to_s.casecmp?(viewer[:email].to_s)
    end

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
        assignee_employee_id: invoice.assigned_employee_id,
        status: invoice.state,
        status_category: queue == 'ready_for_approval' ? :in_review : :pending,
        created_at: invoice.created_at,
        updated_at: invoice.updated_at,
        path: "/aim/invoices/#{ERB::Util.url_encode(invoice.batch_id)}?queue=#{queue}",
        actions: invoice.lock_fresh? ? %i[open release] : %i[open claim],
        metadata: { queue: queue, claimed_by: (invoice.claimed_by if invoice.lock_fresh?), vendor_name: invoice.vendor_name,
                    budget_unit: invoice.budget_unit, assigned_to: invoice.assigned_to },
        source: invoice
      )
    end
  end
end
