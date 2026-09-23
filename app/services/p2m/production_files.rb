# frozen_string_literal: true

require_relative 'paths'

module P2m
  class ProductionFiles
    SAFE_COMPONENT = %r{\A[^./\\][^/\\]*\z}

    def initialize(root: nil)
      @root = root || Paths.printers_store
      @root = Paperboy::FileStore.for(@root) unless @root.respond_to?(:directories)
    end

    def call
      return [] unless root.directory?

      root.directories.sort_by(&:downcase).flat_map do |printer|
        queues(printer)
      end
    end

    def preview(printer:, queue:, filename:)
      [printer, queue, filename].each { |component| validate_component!(component) }
      name = File.join(printer, queue, filename)
      raise ArgumentError, 'file not found' unless root.files(File.join(printer, queue)).include?(filename)

      root.download(name)
    end

    private

    attr_reader :root

    def queues(printer)
      root.directories(printer).sort_by(&:downcase).filter_map do |queue|
        files = root.files(File.join(printer, queue)).sort_by(&:downcase)
        next if files.empty?

        {
          'printer' => printer,
          'queue' => queue,
          'files' => files,
          'modified_at' => files.filter_map { |name| root.mtime(File.join(printer, queue, name)) }.max
        }
      end
    end

    def validate_component!(component)
      raise ArgumentError, 'invalid production file path' unless component.to_s.match?(SAFE_COMPONENT)
    end
  end
end
