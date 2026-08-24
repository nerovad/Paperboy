# frozen_string_literal: true

class DslCatalog
  CONTROL_CENTER_EXCLUDED_GROUPS = %w[print_2_mail print_2_mail_billing_data].freeze

  Entry = Data.define(:key, :slug, :path, :config) do
    def group
      config.dig(:group, :name).presence
    end

    def output_name
      config[:output] || config.dig(:source, :local)
    end

    def sop
      configured = config[:sop]
      return if configured.nil?

      shared = configured[:shared]
      return configured if shared.nil?

      DslSharedSop.fetch!(shared).merge(configured.except(:shared))
    end

    def sop_reference_path
      path = sop&.fetch(:reference_path, nil)
      return config.dig(:source, :location) if path == :source_location
      return downloaded_reference_path if path == :downloaded_file

      path
    end

    def downloaded_reference_path
      return WorkflowPaths::OUTPUT_ROOT.join(WorkflowPaths::DOWNLOAD_DIR_NAME, output_name) if output_name.present?

      orchestration = config.fetch(:orchestration)
      queue_path = orchestration.dig(:queue, :path)
      queue_path = orchestration.fetch(queue_path) if queue_path.is_a?(Symbol)
      Pathname.new(orchestration.fetch(:root_path)).join(queue_path)
    end
    private :downloaded_reference_path

    def sop_reference_group
      reference = sop&.fetch(:reference_group, nil)
      reference == :source_group ? group : reference
    end

    def enabled?
      Workflow.steps_enabled?(config)
    end
  end

  class << self
    def entries
      @entries ||= load_entries.sort_by { |entry| entry.key.downcase }
    end

    def find!(slug)
      entries.find { |entry| entry.slug == slug } || raise(ActiveRecord::RecordNotFound, 'Unknown DSL')
    end

    def grouped
      entries.select(&:group).group_by(&:group).sort.to_h
    end

    def control_center_grouped
      grouped.except(*CONTROL_CENTER_EXCLUDED_GROUPS)
    end

    def ungrouped
      entries.reject(&:group)
    end

    def reload!
      @entries = nil
    end

    private

    def load_entries
      require Rails.root.join('script/ruby/data_runner/constants/workflow')
      require Rails.root.join('script/ruby/data_runner/constants/workflow_paths')
      Rails.root.glob('config/data_runner/dsl/*.rb').map do |path|
        key, config = TOPLEVEL_BINDING.eval(path.read, path.to_s)
        Entry.new(key: key, slug: path.basename('.rb').to_s, path: path, config: config)
      end
    end
  end
end
