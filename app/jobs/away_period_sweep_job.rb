# frozen_string_literal: true

# Hands over the inbox of everybody who is away today.
#
# Runs daily rather than only when a period is saved, for two reasons: a period
# booked in advance has to start on its own, and anything a redirect missed —
# work assigned by a path that does not go through AwayPeriod.assignee_for —
# gets picked up the next morning instead of sitting unread for a fortnight.
#
# AwayReassignment is idempotent, so re-sweeping a period already handed over
# finds nothing to do.
class AwayPeriodSweepJob < ApplicationJob
  queue_as :default

  def perform(on: Date.current)
    periods = AwayPeriod.covering(on).to_a
    Rails.logger.info("Away sweep: #{periods.size} period(s) active on #{on}")

    periods.each do |period|
      result = AwayReassignment.new(period).call
      next if result.moved.zero? && result.skipped.zero?

      Rails.logger.info(
        "Away sweep: moved #{result.moved} task(s) from #{period.employee_id} " \
        "to #{period.delegate_id} (#{result.skipped} skipped)"
      )
    rescue StandardError => e
      Rails.logger.error("Away sweep failed for period ##{period.id}: #{e.message}")
    end
  end
end
