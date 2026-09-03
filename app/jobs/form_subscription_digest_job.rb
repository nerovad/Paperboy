# frozen_string_literal: true

# Sends the daily rollup for everyone on digest delivery — see
# Forms::Subscription and Forms::SubscriptionDigest.
#
# The window is passed explicitly rather than assumed to be "since yesterday" so
# a missed run can be replayed for the day it covered, and so a test can ask for
# any window at all. One mail per subscriber, skipped entirely when their day
# was quiet.
class FormSubscriptionDigestJob < ApplicationJob
  queue_as :default

  def perform(since: nil, through: nil)
    through ||= Time.current
    since ||= through - 1.day

    employee_ids = digest_subscriber_ids
    Rails.logger.info("Form subscription digest: #{employee_ids.size} subscriber(s) for #{since}..#{through}")

    employee_ids.each do |employee_id|
      deliver_for(employee_id, since, through)
    rescue StandardError => e
      # One bad subscriber must not cost everyone else their digest.
      Rails.logger.error("Form subscription digest failed for #{employee_id}: #{e.message}")
    end
  end

  private

  def deliver_for(employee_id, since, through)
    digest = Forms::SubscriptionDigest.new(employee_id: employee_id, since: since, through: through)
    return unless digest.any?

    FormSubscriptionMailer.daily_digest(employee_id, since, through).deliver_later
  end

  # Everyone a digest could reach: the employees holding a digest subscription
  # directly, plus the members of every group holding one.
  def digest_subscriber_ids
    Forms::Subscription.expand_recipients(Forms::Subscription.daily_digest)
  end
end
