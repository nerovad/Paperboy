# frozen_string_literal: true

require 'fileutils'
require 'pathname'

module P2m
  class OmsShippingStation
    DESTINATION = Pathname.new('/mnt/o/Outputs/DataRunner/00_ShippingStation')

    def initialize(root: OmsAssociatedFiles::ROOT, destination: DESTINATION)
      @root = Pathname.new(root).expand_path
      @destination = Pathname.new(destination).expand_path
      @associated_files = OmsAssociatedFiles.new(root: @root)
    end

    def copy(directory:, oms_number:)
      name = maildat_name(directory, oms_number)
      destination.mkpath
      source = root.join(directory, name)
      target = destination.join(name)
      return 1 if matching_file?(source, target)
      raise "shipping station file already exists with different contents: #{name}" if target.exist?

      FileUtils.cp(source, target, preserve: true)
      1
    end

    def remove(directory:, oms_number:)
      path = destination.join(maildat_name(directory, oms_number))
      return 0 unless path.file?

      FileUtils.rm_f(path)
      1
    end

    private

    attr_reader :root, :destination, :associated_files

    def maildat_name(directory, oms_number)
      name = associated_files.call(directory: directory, oms_number: oms_number).find do |file|
        file.match?(/\AMail\.dat_#{Regexp.escape(oms_number)}\.zip\z/i)
      end
      raise ArgumentError, "Mail.dat file not found for OMS #{oms_number}" unless name

      name
    end

    def matching_file?(source, target)
      target.file? && source.size == target.size && source.mtime == target.mtime
    end
  end
end
