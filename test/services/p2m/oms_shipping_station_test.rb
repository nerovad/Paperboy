# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require_relative '../../../app/services/p2m/oms_associated_files'
require_relative '../../../app/services/p2m/oms_shipping_station'

class P2mOmsShippingStationTest < Minitest::Test
  def test_copies_and_removes_only_the_maildat_file
    Dir.mktmpdir do |directory|
      root = Pathname.new(directory).join('Outputs')
      source = root.join('job')
      destination = root.join('DataRunner/00_ShippingStation')
      source.mkpath
      source.join('Mail.dat_50000001.zip').write('maildat')
      source.join('50000001-companion.csv').write('companion')
      shipping_station = P2m::OmsShippingStation.new(root: root, destination: destination)

      assert_equal 1, shipping_station.copy(directory: 'job', oms_number: '50000001')
      names = destination.children.map { |path| path.basename.to_s }
      assert_equal ['Mail.dat_50000001.zip'], names
      assert_equal 1, shipping_station.remove(directory: 'job', oms_number: '50000001')
      assert_empty destination.children
    end
  end
end
