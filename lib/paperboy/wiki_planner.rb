# frozen_string_literal: true

require 'json'

module Paperboy
  # Decides which wiki files to write, delete, or leave untouched.
  class WikiPlanner
    def initialize(catalog)
      @catalog = catalog
    end

    def classify(staged, existing)
      write = staged.keys.reject { |name| existing[name] == staged[name] }.sort
      {
        'write' => write,
        'unchanged' => (staged.keys - write).sort,
        'delete' => [],
        'retain' => [],
        'unmanaged' => []
      }.tap { |plan| classify_existing(plan, staged, existing) }
    end

    def report(plan)
      [
        section('Write', plan['write']),
        section('Unchanged', plan['unchanged']),
        section('Delete', plan['delete']),
        section('Leave on wiki', plan['retain']),
        section('Leave unmanaged', plan['unmanaged'])
      ].compact.join("\n")
    end

    def self.read_tree(dir)
      return {} unless dir && File.directory?(dir)

      Dir.children(dir).select { |name| name.end_with?('.md') }.to_h do |name|
        [name, File.read(File.join(dir, name), encoding: 'UTF-8')]
      end
    end

    private

    def classify_existing(plan, staged, existing)
      existing.each do |name, content|
        next if staged.key?(name)

        bucket = bucket_for(content)
        plan[bucket] << name
      end
      %w[delete retain unmanaged].each { |bucket| plan[bucket].sort! }
    end

    def bucket_for(content)
      source = content.to_s.match(WikiCatalog::SOURCE_MARKER)&.[](1)
      return 'unmanaged' if source.nil?
      return 'retain' if source.start_with?('generated-') || @catalog.include_source?(source)

      'delete'
    end

    def section(title, names)
      return if names.empty?

      ([title] + names.map { |name| "  #{name}" }).join("\n")
    end
  end
end
