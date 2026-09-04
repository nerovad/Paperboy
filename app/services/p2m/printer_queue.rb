# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require_relative 'paths'

module P2m
  class PrinterQueue
    DESTINATION = Paths::PRINTERS_PATH
    SAFE_COMPONENT = %r{\A[^./\\][^/\\]*\z}

    def initialize(root: OmsAssociatedFiles::ROOT, destination: DESTINATION)
      @root = Pathname.new(root).expand_path
      @destination = Pathname.new(destination).expand_path
      @associated_files = OmsAssociatedFiles.new(root: @root)
    end

    def copy(directory:, oms_number:, printer:, queue:, filenames: nil)
      validate_component!(printer, 'printer')
      validate_component!(queue, 'queue')
      available = associated_files.call(directory: directory, oms_number: oms_number)
      selected = Array(filenames)
      selected = available if selected.empty?
      invalid = selected - available
      raise ArgumentError, "associated file not found: #{invalid.first}" if invalid.any?
      raise ArgumentError, 'select at least one file' if selected.empty?

      target_directory = destination.join(printer, queue)
      target_directory.mkpath
      selected.each do |name|
        source = root.join(directory, name)
        target = target_directory.join(name)
        next if matching_file?(source, target)
        raise "printer queue file already exists with different contents: #{name}" if target.exist?

        FileUtils.cp(source, target, preserve: true)
      end
      selected.length
    end

    def remove(directory:, oms_number:, printer:, queue:, filenames:)
      validate_component!(printer, 'printer')
      validate_component!(queue, 'queue')
      available = associated_files.call(directory: directory, oms_number: oms_number)
      selected = Array(filenames)
      invalid = selected - available
      raise ArgumentError, "associated file not found: #{invalid.first}" if invalid.any?
      raise ArgumentError, 'select at least one file' if selected.empty?

      target_directory = destination.join(printer, queue)
      selected.count do |name|
        target = target_directory.join(name)
        next false unless target.file?

        FileUtils.rm_f(target)
        true
      end
    end

    private

    attr_reader :root, :destination, :associated_files

    def validate_component!(value, label)
      raise ArgumentError, "invalid #{label}" unless value.to_s.match?(SAFE_COMPONENT)
    end

    def matching_file?(source, target)
      target.file? && source.size == target.size && source.mtime == target.mtime
    end
  end
end
