# frozen_string_literal: true

require 'test_helper'

module Billing
  class EmailDeliveryTest < ActiveSupport::TestCase
    test 'increments the period only after every report is delivered' do
      active_period = period
      delivery = EmailDelivery.new(reports: [], active_period: active_period)
      mailer = Object.new
      mailer.define_singleton_method(:deliver_now) { true }

      delivery.stub(:messages, messages(2)) do
        BillingReportMailer.stub(:billing_report, mailer) do
          delivery.deliver(['billing@example.gov'])
        end
      end

      assert_equal 2, active_period.version
    end

    test 'does not increment the period when a report delivery fails' do
      active_period = period
      delivery = EmailDelivery.new(reports: [], active_period: active_period)
      deliveries = 0
      mailer = Object.new
      mailer.define_singleton_method(:deliver_now) do
        deliveries += 1
        raise StandardError, 'delivery failed' if deliveries == 2
      end

      delivery.stub(:messages, messages(2)) do
        BillingReportMailer.stub(:billing_report, mailer) do
          assert_raises(StandardError) { delivery.deliver(['billing@example.gov']) }
        end
      end

      assert_equal 1, active_period.version
    end

    private

    def period
      Struct.new(:fiscal_year, :apmon, :version) do
        def increment_version!
          self.version += 1
        end
      end.new('FY27', 'AP01', 1)
    end

    def messages(count)
      Array.new(count) do |index|
        EmailDelivery::Message.new(
          report_name: "report-#{index}", subject: 'subject', body: 'body', attachments: []
        )
      end
    end
  end
end
