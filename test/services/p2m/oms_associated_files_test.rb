# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require_relative '../../../app/services/p2m/oms_associated_files'

class P2mOmsAssociatedFilesTest < Minitest::Test
  def test_finds_only_files_for_the_requested_oms_number
    Dir.mktmpdir do |root|
      directory = Pathname.new(root).join('job')
      directory.mkpath
      expected = %w[
        50000001-companion.csv
        Mail.dat_50000001.zip
        MoveResults_50000001.txt
      ]
      (expected + ['50000002-companion.csv']).each { |name| directory.join(name).write('fixture') }

      files = P2m::OmsAssociatedFiles.new(root: root).call(directory: 'job', oms_number: '50000001')

      assert_equal expected, files
    end
  end
end
