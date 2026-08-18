# frozen_string_literal: true

module Aim
  class WorkProvider < Pfa::Work::Provider
    WORK_QUEUES = %i[action_needed vendor_review manual_processing batch_split low_confidence_review user_approval].freeze

    def initialize(directory_service: InvoiceDirectoryService.instance)
      super()
      @directory_service = directory_service
    end

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
      queues(filters).flat_map { |queue| items_in(queue) }
    end

    def queues(filters)
      requested = filters[:queue].presence&.to_sym
      requested && WORK_QUEUES.include?(requested) ? [requested] : WORK_QUEUES
    end

    def items_in(queue)
      path = @directory_service.path_for(queue)
      return [] unless path.present? && Dir.exist?(path)

      Dir.children(path).filter_map do |name|
        folder = File.join(path, name)
        item_for(queue, name, folder) if File.directory?(folder)
      end
    rescue SystemCallError => e
      Rails.logger.warn("AIM work queue #{queue} is unavailable: #{e.message}")
      []
    end

    def item_for(queue, invoice_id, folder)
      stat = File.stat(folder)
      claimed_by = claim_owner(folder)
      Pfa::Work::Item.new(
        key: "aim:invoice:#{queue}:#{invoice_id}",
        application: :aim,
        source_type: 'Aim::Invoice',
        source_id: invoice_id,
        reference: invoice_id,
        title: InvoiceDirectoryService::BACKEND_QUEUES.dig(queue, :label) || queue.to_s.humanize,
        assignee_employee_id: claimed_by,
        status: queue.to_s,
        status_category: status_category(queue),
        created_at: stat.ctime,
        updated_at: stat.mtime,
        path: "/aim/invoices/#{ERB::Util.url_encode(invoice_id)}?queue=#{queue}",
        actions: claimed_by.present? ? %i[open release] : %i[open claim],
        metadata: { queue: queue, claimed_by: claimed_by, folder: folder }
      )
    end

    def claim_owner(folder)
      claim_path = File.join(folder, '.claim.json')
      return unless File.file?(claim_path)

      data = JSON.parse(File.read(claim_path))
      data['user'] || data['employee_id']
    rescue JSON::ParserError, SystemCallError
      'Unknown'
    end

    def status_category(queue)
      queue == :user_approval ? :in_review : :pending
    end
  end
end
