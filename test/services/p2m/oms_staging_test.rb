# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require_relative '../../../app/services/p2m/oms_associated_files'
require_relative '../../../app/services/p2m/oms_staging'

class P2mOmsStagingTest < Minitest::Test
  def test_stages_and_removes_only_associated_oms_files
    Dir.mktmpdir do |directory|
      root = Pathname.new(directory).join('Outputs')
      source = root.join('job')
      destination = root.join('DataRunner/00_SentToUSPS')
      source.mkpath
      names = ['Mail.dat_50000001.zip', '50000001-companion.csv']
      names.each { |name| source.join(name).write('fixture') }
      source.join('50000002-companion.csv').write('other')
      staging = P2m::OmsStaging.new(root: root, destination: destination)

      assert_equal 2, staging.stage(directory: 'job', oms_number: '50000001')
      assert_equal names.sort, destination.children.map { |path| path.basename.to_s }.sort
      assert_equal 2, staging.remove(directory: 'job', oms_number: '50000001')
      assert_empty destination.children
    end
  end
end
