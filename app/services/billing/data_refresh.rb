# frozen_string_literal: true

module Billing
  class DataRefresh
    Group = Data.define(:key, :label, :default, :enabled_dsl_count)

    GROUPS = {
      'billing' => { label: 'Billing', default: true },
      'mail_center_and_warehousing' => { label: 'Mail Center and Warehousing', default: false }
    }.freeze
    VALUES = %w[0 1].freeze

    def self.groups
      catalog = DslCatalog.grouped
      GROUPS.map do |key, configuration|
        entries = catalog.fetch(key)
        Group.new(
          key: key,
          label: configuration.fetch(:label),
          default: configuration.fetch(:default),
          enabled_dsl_count: entries.count(&:enabled?)
        )
      end
    end

    def self.run!(values)
      validate!(values)
      selected_groups = GROUPS.keys.select { |key| values.fetch(key) == '1' }
      return if selected_groups.empty?

      TaskRunner.run!(task: 'refresh', selector: enabled_slugs(selected_groups))
    end

    def self.enabled_slugs(group_keys)
      catalog = DslCatalog.grouped
      group_keys.flat_map do |key|
        catalog.fetch(key).select(&:enabled?).map(&:slug)
      end
    end
    private_class_method :enabled_slugs

    def self.validate!(values)
      raise ArgumentError unless values.keys.sort == GROUPS.keys.sort
      raise ArgumentError unless values.values.all? { |value| VALUES.include?(value) }
    end
    private_class_method :validate!
  end
end
