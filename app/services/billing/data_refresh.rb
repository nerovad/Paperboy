# frozen_string_literal: true

module Billing
  class DataRefresh
    Dsl = Data.define(:name, :slug, :location, :file_date, :current, :script, :sop) do
      def sop_reference_path
        path = sop&.fetch(:reference_path, nil)
        path == :source_location ? location : path
      end

      def sop_reference_group
        sop&.fetch(:reference_group, nil)
      end
    end
    Group = Data.define(:key, :label, :default, :enabled_dsls) do
      def enabled_dsl_count = enabled_dsls.size
    end

    GROUPS = {
      'billing' => { label: 'Billing', default: true },
      'mail_center_and_warehousing' => { label: 'Mail Center and Warehousing', default: false }
    }.freeze
    VALUES = %w[0 1].freeze
    GROUP_RUN_NAME = 'billing_data_refresh'

    def self.groups(end_date: nil)
      catalog = DslCatalog.grouped
      GROUPS.map do |key, configuration|
        entries = catalog.fetch(key).select(&:enabled?)
        Group.new(
          key: key,
          label: configuration.fetch(:label),
          default: configuration.fetch(:default),
          enabled_dsls: entries.map { |entry| dsl_status(entry, end_date) }
        )
      end
    end

    def self.dsl_status(entry, end_date)
      source = entry.config.fetch(:source)
      return script_status(entry, source) if source[:strategy] == :script

      file_date = File.mtime(source[:location])
      Dsl.new(
        name: entry.key, slug: entry.slug, location: source[:location], file_date: file_date,
        current: end_date.present? && file_date.to_date > end_date + 1, script: false, sop: entry.sop
      )
    rescue SystemCallError, TypeError
      Dsl.new(
        name: entry.key, slug: entry.slug, location: entry.config.dig(:source, :location),
        file_date: nil, current: false, script: false, sop: entry.sop
      )
    end
    private_class_method :dsl_status

    def self.script_status(entry, source)
      script_name = File.basename(source.dig(:script, :path).to_s)
      Dsl.new(
        name: entry.key, slug: entry.slug, location: script_name, file_date: Date.current,
        current: true, script: true, sop: entry.sop
      )
    end
    private_class_method :script_status

    def self.run!(values, requested_by:)
      validate!(values)
      selected_groups = GROUPS.keys.select { |key| values.fetch(key) == '1' }
      return if selected_groups.empty?

      DataRunner::GroupRefresh.start!(group: GROUP_RUN_NAME, entries: enabled_entries(selected_groups), requested_by: requested_by)
    end

    def self.enabled_entries(group_keys)
      catalog = DslCatalog.grouped
      group_keys.flat_map do |key|
        catalog.fetch(key).select(&:enabled?)
      end
    end
    private_class_method :enabled_entries

    def self.validate!(values)
      raise ArgumentError unless values.keys.sort == GROUPS.keys.sort
      raise ArgumentError unless values.values.all? { |value| VALUES.include?(value) }
    end
    private_class_method :validate!
  end
end
