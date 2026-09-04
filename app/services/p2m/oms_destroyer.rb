# frozen_string_literal: true

require 'fileutils'
require 'pathname'

module P2m
  class OmsDestroyer
    CLEANUP_PATHS = [
      Paths::SHIPPING_STATION_PATH,
      Paths::STAGING_PATH,
      Paths::DATA_RUNNER_ROOT.join(Paths::TEMPORARY_OUTPUT),
      Paths::PROCESSED_PATH,
      Paths::PRINTERS_PATH
    ].freeze

    def initialize(root: OmsAssociatedFiles::ROOT, destination: Paths::DESTROYED_PATH,
                   cleanup_paths: CLEANUP_PATHS)
      @root = Pathname.new(root).expand_path
      @destination = Pathname.new(destination).expand_path
      @cleanup_paths = cleanup_paths.map { |path| Pathname.new(path).expand_path }
      @associated_files = OmsAssociatedFiles.new(root: @root)
    end

    def call(directory:, oms_number:)
      filenames = associated_files.call(directory: directory, oms_number: oms_number)
      raise ArgumentError, "no files found for OMS #{oms_number}" if filenames.empty?

      archive = destination.join(oms_number.to_s)
      raise ArgumentError, "destroyed OMS #{oms_number} already exists" if archive.exist?

      archive.mkpath
      filenames.each do |filename|
        FileUtils.cp(root.join(directory, filename), archive.join(filename), preserve: true)
      end
      removed = cleanup_paths.sum { |path| remove_oms_files(path, oms_number.to_s) }
      { archived: filenames.size, removed: removed }
    rescue SystemCallError => e
      raise ArgumentError, e.message
    end

    private

    attr_reader :root, :destination, :cleanup_paths, :associated_files

    def remove_oms_files(path, oms_number)
      return 0 unless path.directory?

      files = path.glob('**/*').select do |candidate|
        candidate.file? && belongs_to_oms?(candidate.relative_path_from(path), oms_number)
      end
      files.each { |file| FileUtils.rm_f(file) }
      prune_empty_directories(path)
      files.size
    end

    def belongs_to_oms?(relative_path, oms_number)
      relative_path.each_filename.include?(oms_number) ||
        relative_path.basename.to_s.match?(/(?<!\d)#{Regexp.escape(oms_number)}(?!\d)/)
    end

    def prune_empty_directories(root_path)
      root_path.glob('**/*').select(&:directory?).sort_by { |path| -path.each_filename.count }.each do |directory|
        directory.rmdir if directory.children.empty?
      end
    end
  end
end
