# frozen_string_literal: true

require 'pathname'
require_relative 'paths'

module P2m
  class OmsShippingStation
    def initialize(root: OmsAssociatedFiles::ROOT, destination: nil)
      @root = Pathname.new(root).expand_path
      @destination = destination || Paths.shipping_station_store
      @destination = Paperboy::FileStore.for(@destination) unless @destination.respond_to?(:copy)
      @associated_files = OmsAssociatedFiles.new(root: @root)
    end

    def copy(directory:, oms_number:)
      name = maildat_name(directory, oms_number)
      source = root.join(directory, name)
      return 1 if destination.exist?(name)

      destination.copy(source, name)
      1
    end

    def remove(directory:, oms_number:)
      destination.remove(maildat_name(directory, oms_number)) ? 1 : 0
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
  end
end
