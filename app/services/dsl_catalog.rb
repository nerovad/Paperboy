# frozen_string_literal: true

class DslCatalog
  SOP_GROUPS = %w[billing mail_center_and_warehousing].freeze

  Entry = Data.define(:key, :slug, :path, :config) do
    def group
      config.dig(:group, :name).presence
    end

    def output_name
      config[:output] || config.dig(:source, :local)
    end

    def sop
      config[:sop] if SOP_GROUPS.include?(group)
    end

    def sop_reference_path
      path = sop&.fetch(:reference_path, nil)
      path == :source_location ? config.dig(:source, :location) : path
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

    def ungrouped
      entries.reject(&:group)
    end

    def reload!
      @entries = nil
    end

    private

    def load_entries
      require Rails.root.join('script/ruby/data_runner/constants/workflow')
      Rails.root.glob('config/data_runner/dsl/*.rb').map do |path|
        key, config = TOPLEVEL_BINDING.eval(path.read, path.to_s)
        Entry.new(key: key, slug: path.basename('.rb').to_s, path: path, config: config)
      end
    end
  end
end
