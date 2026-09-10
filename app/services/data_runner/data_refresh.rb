# frozen_string_literal: true

module DataRunner
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

    VALUES = %w[0 1].freeze

    def self.group_configuration
      const_get(:GROUPS)
    end

    def self.group_run_name
      const_get(:GROUP_RUN_NAME)
    end

    def self.groups(end_date: nil)
      catalog = DslCatalog.grouped
      group_configuration.map do |key, configuration|
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
      orchestration = entry.config[:orchestration]
      return orchestration_status(entry, orchestration) if orchestration

      source = entry.config.fetch(:source)
      return script_status(entry, source) if source[:strategy] == :script

      file_date = File.mtime(source[:location])
      Dsl.new(
        name: entry.key, slug: entry.slug, location: source[:location], file_date: file_date,
        current: end_date.present? && file_date.to_date > end_date, script: false, sop: entry.sop
      )
    rescue SystemCallError, TypeError
      Dsl.new(
        name: entry.key, slug: entry.slug, location: entry.config.dig(:source, :location),
        file_date: nil, current: false, script: false, sop: entry.sop
      )
    end
    private_class_method :dsl_status

    def self.orchestration_status(entry, orchestration)
      root_path = orchestration.fetch(:root_path).to_s
      queue_path = orchestration.dig(:queue, :path)
      queue_path = orchestration.fetch(queue_path) if queue_path.is_a?(Symbol)
      location = File.absolute_path(queue_path.to_s, root_path)

      Dsl.new(
        name: entry.key, slug: entry.slug, location: location, file_date: nil,
        current: true, script: true, sop: entry.sop
      )
    end
    private_class_method :orchestration_status

    def self.script_status(entry, source)
      script_name = File.basename(source.dig(:script, :path).to_s)
      Dsl.new(
        name: entry.key, slug: entry.slug, location: script_name, file_date: Date.current,
        current: true, script: true, sop: entry.sop
      )
    end
    private_class_method :script_status

    def self.run!(values, requested_by:, selected_entries: nil)
      validate!(values)
      selected_groups = group_configuration.keys.select { |key| values.fetch(key) == '1' }
      return if selected_groups.empty?

      entries = enabled_entries(selected_groups)
      entries = select_entries(entries, selected_entries)
      return if entries.empty?

      GroupRefresh.start!(group: group_run_name, entries: entries, requested_by: requested_by)
    end

    def self.restart_entries(previous_run)
      previous_run.items.order(:position).map { |item| DslCatalog.find!(item.dsl_slug) }
    end

    def self.enabled_entries(group_keys)
      catalog = DslCatalog.grouped
      group_keys.flat_map do |key|
        catalog.fetch(key).select(&:enabled?)
      end
    end
    private_class_method :enabled_entries

    def self.validate!(values)
      raise ArgumentError unless values.keys.sort == group_configuration.keys.sort
      raise ArgumentError unless values.values.all? { |value| VALUES.include?(value) }
    end
    private_class_method :validate!

    def self.select_entries(entries, _selected_entries)
      entries
    end
    private_class_method :select_entries
  end
end
