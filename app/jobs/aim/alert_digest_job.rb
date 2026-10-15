# frozen_string_literal: true

module Aim
  # The daily AIM alert digest (#131), at 7am (config/recurring.yml). Does
  # nothing unless AIM_EMAIL_ALERTS=on.
  class AlertDigestJob < ApplicationJob
    queue_as :default

    def perform
      return unless Aim::Alerts.enabled?

      Aim::Alerts.new.digests.each do |employee_id, kinds|
        Aim::AlertMailer.digest(employee_id, kinds.transform_values { |invoices| invoices.map(&:id).uniq }).deliver_now
      rescue StandardError => e
        Rails.logger.error "AIM alert digest for #{employee_id} not sent: #{e.class}: #{e.message}"
      end
    end
  end
end
