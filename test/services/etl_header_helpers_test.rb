# frozen_string_literal: true

require 'test_helper'
require Rails.root.join('script/ruby/data_runner/helpers/etl_header_helpers')

class EtlHeaderHelpersTest < ActiveSupport::TestCase
  test 'cleanup uses authoritative header when column counts match' do
    with_header_files do |input, output|
      input.write("Item,Item #\nEnvelope,1\n")
      EtlHeaderHelpers.cleanup_one(input, output, authoritative_header: %w[item item1])
      assert_equal "item,item1\n", output.each_line.first
    end
  end

  test 'cleanup falls back to normalized header when authoritative count differs' do
    with_header_files do |input, output|
      input.write("Item,Item #\nEnvelope,1\n")
      EtlHeaderHelpers.cleanup_one(input, output, authoritative_header: ['item'])
      assert_equal "item,item_2\n", output.each_line.first
    end
  end

  private

  def with_header_files
    Dir.mktmpdir('etl-header-helper-') do |directory|
      paths = Pathname.new(directory)
      yield paths.join('input.csv'), paths.join('output.csv')
    end
  end
end
