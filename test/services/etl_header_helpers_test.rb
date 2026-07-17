# frozen_string_literal: true

require 'test_helper'
require Rails.root.join('script/ruby/data_runner/helpers/etl_header_helpers')

class EtlHeaderHelpersTest < ActiveSupport::TestCase
  test 'cleanup uses authoritative header when column counts match' do
    input = Rails.root.join('tmp', 'header_helper_input.csv')
    output = Rails.root.join('tmp', 'header_helper_output.csv')
    input.write("Item,Item #\nEnvelope,1\n")

    EtlHeaderHelpers.cleanup_one(input, output, authoritative_header: %w[item item1])

    assert_equal "item,item1\n", output.each_line.first
  ensure
    input&.delete if input&.file?
    output&.delete if output&.file?
  end

  test 'cleanup falls back to normalized header when authoritative count differs' do
    input = Rails.root.join('tmp', 'header_helper_input.csv')
    output = Rails.root.join('tmp', 'header_helper_output.csv')
    input.write("Item,Item #\nEnvelope,1\n")

    EtlHeaderHelpers.cleanup_one(input, output, authoritative_header: ['item'])

    assert_equal "item,item_2\n", output.each_line.first
  ensure
    input&.delete if input&.file?
    output&.delete if output&.file?
  end
end
