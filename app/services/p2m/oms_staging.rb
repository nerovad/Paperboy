# frozen_string_literal: true

require 'fileutils'
require 'pathname'

module P2m
  class OmsStaging
    DESTINATION = Pathname.new('/mnt/o/Outputs/DataRunner/00_SentToUSPS')

    def initialize(root: OmsAssociatedFiles::ROOT, destination: DESTINATION)
      @root = Pathname.new(root).expand_path
      @destination = Pathname.new(destination).expand_path
      @associated_files = OmsAssociatedFiles.new(root: @root)
    end

    def stage(directory:, oms_number:)
      files = associated_files.call(directory: directory, oms_number: oms_number)
      destination.mkpath
      files.each { |name| copy(root.join(directory, name), destination.join(name)) }
      files.length
    end

    def remove(directory:, oms_number:)
      files = associated_files.call(directory: directory, oms_number: oms_number)
      files.count do |name|
        path = destination.join(name)
        next false unless path.file?

        FileUtils.rm_f(path)
        true
      end
    end

    private

    attr_reader :root, :destination, :associated_files

    def copy(source, target)
      return if matching_file?(source, target)
      raise "staged file already exists with different contents: #{target.basename}" if target.exist?

      FileUtils.cp(source, target, preserve: true)
    end

    def matching_file?(source, target)
      target.file? && source.size == target.size && source.mtime == target.mtime
    end
  end
end
