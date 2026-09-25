# frozen_string_literal: true

require 'fileutils'
require 'digest'
require 'pathname'
require_relative 'paths'

module P2m
  class OmsStaging
    DESTINATION = Paths::STAGING_PATH

    def initialize(root: OmsAssociatedFiles::ROOT, destination: nil)
      @root = Pathname.new(root).expand_path
      @destination = destination || Paths.staging_store
      @destination = Paperboy::FileStore.for(@destination) unless @destination.respond_to?(:copy)
      @associated_files = OmsAssociatedFiles.new(root: @root)
    end

    def stage(directory:, oms_number:, checksums: nil)
      files = associated_files.call(directory: directory, oms_number: oms_number)
      files.each do |name|
        checksum = copy(root.join(directory, name), name)
        checksums[name] = checksum if checksums
      end
      files.length
    end

    def remove(directory:, oms_number:)
      files = associated_files.call(directory: directory, oms_number: oms_number)
      files.count do |name|
        destination.remove(name)
      end
    end

    private

    attr_reader :root, :destination, :associated_files

    def copy(source, name)
      checksum = Digest::SHA256.file(source).hexdigest
      destination.copy(source, name) unless destination.exist?(name)
      checksum
    end
  end
end
