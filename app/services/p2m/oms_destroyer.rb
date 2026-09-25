# frozen_string_literal: true

require 'pathname'
require_relative 'paths'

module P2m
  class OmsDestroyer
    CLEANUP_PATHS = [
      Paths.shipping_station_store,
      Paths.staging_store,
      Paths.temporary_output_store,
      Paths.processed_store,
      Paths.printers_store
    ].freeze

    def initialize(root: OmsAssociatedFiles::ROOT, destination: nil,
                   cleanup_paths: CLEANUP_PATHS)
      @root = Pathname.new(root).expand_path
      @destination = destination || Paths.destroyed_store
      @destination = Paperboy::FileStore.for(@destination) unless @destination.respond_to?(:copy)
      @cleanup_paths = cleanup_paths.map { |path| file_store(path) }
      @associated_files = OmsAssociatedFiles.new(root: @root)
    end

    def call(directory:, oms_number:)
      filenames = associated_files.call(directory: directory, oms_number: oms_number)
      raise ArgumentError, "no files found for OMS #{oms_number}" if filenames.empty?

      archive = oms_number.to_s
      raise ArgumentError, "destroyed OMS #{oms_number} already exists" if directory_exists?(destination, archive)

      filenames.each do |filename|
        destination.copy(root.join(directory, filename), File.join(archive, filename))
      end
      removed = cleanup_paths.sum { |path| remove_oms_files(path, oms_number.to_s) }
      { archived: filenames.size, removed: removed }
    rescue SystemCallError => e
      raise ArgumentError, e.message
    end

    private

    attr_reader :root, :destination, :cleanup_paths, :associated_files

    def remove_oms_files(store, oms_number, prefix = nil)
      return 0 unless store.directory?

      directories = []
      removed = store.entries(prefix).sum do |entry|
        name = [prefix, entry.fetch(:name)].compact.join('/')
        if entry.fetch(:directory)
          directories << name
          remove_oms_files(store, oms_number, name)
        elsif belongs_to_oms?(name, oms_number) && store.remove(name)
          1
        else
          0
        end
      end
      directories.reverse_each { |name| store.rmdir(name) }
      removed
    end

    def belongs_to_oms?(relative_path, oms_number)
      path = Pathname.new(relative_path)
      path.each_filename.include?(oms_number) ||
        path.basename.to_s.match?(/(?<!\d)#{Regexp.escape(oms_number)}(?!\d)/)
    end

    def file_store(path)
      return path if path.respond_to?(:copy)

      Paperboy::FileStore.for(path)
    end

    def directory_exists?(store, name)
      store.entries(name)
      true
    rescue StandardError
      false
    end
  end
end
