# frozen_string_literal: true

module DataRunner
  class GroupRefresh
    class ActiveRun < StandardError; end

    def self.start!(group:, entries:, requested_by:)
      run = nil
      GroupRun.transaction do
        raise ActiveRun if GroupRun.active.where(group_name: group).lock.first

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
  end
end
