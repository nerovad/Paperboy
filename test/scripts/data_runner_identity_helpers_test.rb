# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../script/ruby/data_runner/helpers/identity_helpers'
require_relative '../../script/ruby/data_runner/helpers/etl_mapping_helpers'

class DataRunnerIdentityHelpersTest < Minitest::Test
  def test_preserves_source_identity_parameters_without_integer_overflow
    %w[0 1 -42 99999999999999999999999999999999999999].each do |seed|
      %w[1 7 -3].each do |increment|
        row = { 'seed_value' => seed, 'increment_value' => increment }
        assert_equal "IDENTITY(#{seed},#{increment})", DataRunner::IdentityHelpers.from_metadata(row)
      end
    end
  end

  def test_rejects_unreadable_or_invalid_metadata_instead_of_silently_using_zero
    [nil, '', 'unreadable', '1.5', '0'].each do |increment|
      row = { 'name' => 'id', 'seed_value' => '1', 'increment_value' => increment }
      assert_raises(ArgumentError) { DataRunner::IdentityHelpers.from_metadata(row) }
    end
    assert_raises(ArgumentError) do
      DataRunner::IdentityHelpers.from_metadata({ 'seed_value' => nil, 'increment_value' => '1' })
    end
  end

  def test_repairs_legacy_dsl_identity_in_sql_without_losing_csv_ids
    config = { header: [['source_id', 'id', 'bigint', 'identity ( 0, 0 ) NOT NULL', nil]] }

    assert_equal 'IDENTITY(0,1) NOT NULL', EtlMappingHelpers.output_columns(config).first[:nullability]
    mapping = EtlMappingHelpers.csv_mapping(config).first
    assert mapping[:identity]
    assert_equal 'source_id', mapping[:input]
  end

  def test_leaves_valid_identity_and_non_identity_clauses_unchanged
    ['IDENTITY(0,1) NOT NULL', 'IDENTITY(100,5) NOT NULL',
     'IDENTITY(-1,-1) NOT NULL', 'NOT NULL', 'NULL'].each do |clause|
      assert_equal clause, DataRunner::IdentityHelpers.normalize(clause)
    end
  end
end
