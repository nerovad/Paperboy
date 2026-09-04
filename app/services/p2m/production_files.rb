# frozen_string_literal: true

require 'pathname'
require_relative 'paths'

module P2m
  class ProductionFiles
    ROOT = Paths::PRINTERS_PATH
    SAFE_COMPONENT = %r{\A[^./\\][^/\\]*\z}

    def initialize(root: ROOT)
      @root = Pathname.new(root).expand_path
    end

    def call
      return [] unless root.directory?

      root.children.select(&:directory?).sort_by { |path| path.basename.to_s.downcase }.flat_map do |printer|
        queues(printer)
      end
    end

    def preview(printer:, queue:, filename:)
      [printer, queue, filename].each { |component| validate_component!(component) }
      file = root.join(printer, queue, filename)
      raise ArgumentError, 'file not found' unless file.file?

      file = file.realpath
      raise ArgumentError, 'invalid production file path' unless file.to_s.start_with?("#{root.realpath}/")

      file
    end

    private

    attr_reader :root

    def queues(printer)
      printer.children.select(&:directory?).sort_by { |path| path.basename.to_s.downcase }.filter_map do |queue|
        files = queue.children.select(&:file?).sort_by { |path| path.basename.to_s.downcase }
        next if files.empty?

        {
          'printer' => printer.basename.to_s,
          'queue' => queue.basename.to_s,
          'files' => files.map { |path| path.basename.to_s },
          'modified_at' => files.map(&:mtime).max
        }
      end
    end

    def validate_component!(component)
      raise ArgumentError, 'invalid production file path' unless component.to_s.match?(SAFE_COMPONENT)
    end
  end
end
