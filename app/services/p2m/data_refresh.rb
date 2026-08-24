# frozen_string_literal: true

module P2m
  class DataRefresh < DataRunner::DataRefresh
    QueueEntry = Data.define(:key, :slug)
    OMS_MARKER = /\AMail\.dat_(\d{8,9})\.zip\z/i

    GROUPS = {
      'print_2_mail' => { label: 'Print 2 Mail', default: false },
      'print_2_mail_billing_data' => { label: 'Print 2 Mail Billing Data', default: true }
    }.freeze
    GROUP_RUN_NAME = 'p2m_data_refresh'

    def self.enabled_entries(group_keys)
      super.flat_map do |entry|
        queue_path = oms_queue_path(entry)
        next entry unless queue_path

        queued_oms_entries(entry, queue_path)
      end
    end
    private_class_method :enabled_entries

    def self.queued_oms_entries(entry, queue_path)
      Pathname.new(queue_path).children.filter_map do |path|
        match = path.file? && path.basename.to_s.match(OMS_MARKER)
        QueueEntry.new(key: "OMS #{match[1]}", slug: entry.slug) if match
      end.sort_by(&:key)
    rescue SystemCallError
      []
    end
    private_class_method :queued_oms_entries

    def self.oms_queue_path(entry)
      return unless entry.respond_to?(:config)

      orchestration = entry.config[:orchestration]
      return unless orchestration&.dig(:queue)

      root = orchestration.fetch(:root_path).to_s
      path = orchestration.dig(:queue, :path)
      path = orchestration.fetch(path) if path.is_a?(Symbol)
      File.absolute_path(path.to_s, root)
    rescue KeyError, SystemCallError
      nil
    end
    private_class_method :oms_queue_path
  end
end
