# frozen_string_literal: true

module DataRunner
  class GroupRefresh
    class ActiveRun < StandardError; end
    class QueueUnavailable < StandardError; end

    def self.start!(group:, entries:, requested_by:)
      create!(group: group, entries: entries, requested_by: requested_by)
    end

    def self.restart!(group:, entries:, requested_by:)
      create!(group: group, entries: entries, requested_by: requested_by, restart: true)
    end

    def self.create!(group:, entries:, requested_by:, restart: false)
      validate_entries!(group, entries)
      run = nil
      GroupRun.transaction do
        active_run = GroupRun.active.where(group_name: group).lock.first
        raise ActiveRun if active_run && !restart

        interrupt!(active_run) if active_run

        run = GroupRun.create!(run_id: SecureRandom.uuid, group_name: group,
                               total_count: entries.size, requested_by: requested_by)
        entries.each_with_index do |entry, position|
          run.items.create!(dsl_name: entry.key, dsl_slug: entry.slug, position: position)
        end
      end
      enqueue!(run.id)
      run
    rescue StandardError
      run&.update(status: 'failed', completed_at: Time.current) if run&.persisted?
      raise
    end

    # Delete the run and its items. Marking them failed left the worker and its
    # rake children going, and the next refresh still saw that run. The worker
    # notices the row is gone, kills those children, and the replacement starts
    # with every DSL pending.
    private_class_method def self.interrupt!(run)
      run.destroy!
    end

    private_class_method def self.enqueue!(run_id)
      GroupRefreshJob.perform_later(run_id)
    rescue StandardError => e
      raise QueueUnavailable, e.message if queue_connection_error?(e)

      raise
    end

    private_class_method def self.queue_connection_error?(error)
      error_chain(error).any?(Errno::ECONNREFUSED)
    end

    private_class_method def self.error_chain(error)
      Enumerator.produce(error, &:cause).take_while(&:present?)
    end

    private_class_method def self.validate_entries!(group, entries)
      return unless group == P2m::DataRefresh::GROUP_RUN_NAME
      return if entries.all? { |entry| entry.key.match?(/\AOMS \d{8,9}\z/) && entry.slug == 'oms' }

      raise ArgumentError, 'Print 2 Mail refresh entries require an OMS number'
    end
  end
end
