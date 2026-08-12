# frozen_string_literal: true

module Billing
  class ArchiveLocation
    class ConfigurationError < StandardError; end

    def self.all(root: configured_root)
      return [] unless root.directory?

      [root, *root.glob('**/').reject(&:symlink?)].uniq.sort.map do |path|
        new(path: path, root: root)
      end
    end

    def self.find(relative_path, root: configured_root)
      location = all(root: root).find { |candidate| candidate.relative_path == relative_path }
      location || raise(ActiveRecord::RecordNotFound)
    end

    def self.configured_root
      value = ENV.fetch('BILLING_ARCHIVE_ROOT', '').strip
      raise ConfigurationError, 'BILLING_ARCHIVE_ROOT is not configured' if value.empty?

      Pathname(value).expand_path
    end

    def initialize(path:, root:)
      @path = path
      @root = root
    end

    attr_reader :path

    def relative_path
      return '.' if path == @root

      path.relative_path_from(@root).to_s
    end

    def label
      relative_path == '.' ? @root.basename.to_s : relative_path
    end
  end
end
