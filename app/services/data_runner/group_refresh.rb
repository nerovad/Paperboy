# frozen_string_literal: true

module DataRunner
  class GroupRefresh
    class ActiveRun < StandardError; end

    def self.start!(group:, entries:, requested_by:)
      create!(group: group, entries: entries, requested_by: requested_by)
    end

    def self.restart!(group:, entries:, requested_by:)
      create!(group: group, entries: entries, requested_by: requested_by, restart: true)
    end

    def self.create!(group:, entries:, requested_by:, restart: false)
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
      GroupRefreshJob.perform_later(run.id)
      run
    rescue StandardError
      run&.update(status: 'failed', completed_at: Time.current) if run&.persisted?
      raise
    end

    private_class_method def self.interrupt!(run)
      now = Time.current
      run.items.where(status: %w[pending running]).update_all(
        status: 'failed', error_message: 'Interrupted refresh was restarted', completed_at: now, updated_at: now
      )
      run.update!(status: 'failed', current_dsl: nil, completed_count: run.total_count,
                  failed_count: run.items.where(status: 'failed').count, completed_at: now)
    end
  end
end
