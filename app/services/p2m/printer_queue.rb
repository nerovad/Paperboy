# frozen_string_literal: true

require 'pathname'
require_relative 'paths'

module P2m
  class PrinterQueue
    SAFE_COMPONENT = %r{\A[^./\\][^/\\]*\z}

    def initialize(root: OmsAssociatedFiles::ROOT, destination: nil)
      @root = Pathname.new(root).expand_path
      @destination = destination || Paths.printers_store
      @destination = Paperboy::FileStore.for(@destination) unless @destination.respond_to?(:copy)
      @associated_files = OmsAssociatedFiles.new(root: @root)
    end

    def copy(directory:, oms_number:, printer:, queue:, filenames: nil)
      validate_component!(printer, 'printer')
      validate_component!(queue, 'queue')
      available = associated_files.call(directory: directory, oms_number: oms_number)
      selected = Array(filenames)
      selected = available.select { |name| File.extname(name).casecmp?('.pdf') } if filenames.nil?
      validate_pdf_filenames!(selected)
      invalid = selected - available
      raise ArgumentError, "associated file not found: #{invalid.first}" if invalid.any?
      raise ArgumentError, 'select at least one file' if selected.empty?

      selected.each do |name|
        source = root.join(directory, name)
        target = File.join(printer, queue, name)
        next if destination.exist?(target)

        destination.mkdir(File.join(printer, queue))
        destination.copy(source, target)
      end
      selected.length
    end

    def remove(directory:, oms_number:, printer:, queue:, filenames: nil)
      validate_component!(printer, 'printer')
      validate_component!(queue, 'queue')
      available = associated_files.call(directory: directory, oms_number: oms_number)
      selected = Array(filenames)
      selected = available.select { |name| File.extname(name).casecmp?('.pdf') } if filenames.nil?
      validate_pdf_filenames!(selected)
      invalid = selected - available
      raise ArgumentError, "associated file not found: #{invalid.first}" if invalid.any?
      raise ArgumentError, 'select at least one file' if selected.empty?

      selected.count do |name|
        destination.remove(File.join(printer, queue, name))
      end
    end

    private

    attr_reader :root, :destination, :associated_files

    def validate_component!(value, label)
      raise ArgumentError, "invalid #{label}" unless value.to_s.match?(SAFE_COMPONENT)
    end

    def validate_pdf_filenames!(filenames)
      invalid = filenames.reject { |name| File.extname(name).casecmp?('.pdf') }
      raise ArgumentError, "only PDF files may be sent to a printer: #{invalid.first}" if invalid.any?
    end
  end
end
