# frozen_string_literal: true

module Billing
  # A Billing Metabase dashboard configured by an environment-specific ID.
  class Dashboard
    DEFINITIONS = {
      'summary' => ['Billing Summary', 'BILLING_SUMMARY_DASHBOARD_ID'],
      'trends' => ['Billing Trends', 'BILLING_TRENDS_DASHBOARD_ID']
    }.freeze

    attr_reader :key, :name, :dashboard_id, :environment_key

    def self.all
      DEFINITIONS.map do |key, (name, environment_key)|
        new(
          key: key,
          name: name,
          environment_key: environment_key,
          dashboard_id: ENV.fetch(environment_key, nil)
        )
      end
    end

    def initialize(key:, name:, environment_key:, dashboard_id:)
      @key = key
      @name = name
      @environment_key = environment_key
      @dashboard_id = dashboard_id.presence
    end

    def configured?
      dashboard_id.present?
    end
  end
end
