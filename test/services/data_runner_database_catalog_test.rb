# frozen_string_literal: true

require 'test_helper'
require Rails.root.join('script/ruby/data_runner/db/mssql_helpers')

class DataRunnerDatabaseCatalogTest < ActiveSupport::TestCase
  test 'formats character lengths and identity for a replication header' do
    column = DataRunnerColumnDefinition.format(
      'name' => 'name', 'type_name' => 'nvarchar', 'type_schema' => 'sys',
      'max_length' => 200, 'precision' => 0, 'scale' => 0,
      'is_nullable' => false, 'is_identity' => false, 'is_computed' => false
    )
    identity = DataRunnerColumnDefinition.format(
      'name' => 'id', 'type_name' => 'int', 'type_schema' => 'sys',
      'max_length' => 4, 'precision' => 10, 'scale' => 0,
      'is_nullable' => false, 'is_identity' => true, 'is_computed' => false,
      'seed_value' => '1', 'increment_value' => '1'
    )

    assert_equal({ name: 'name', data_type: 'nvarchar(100)', nullability: 'NOT NULL' }, column)
    assert_equal 'IDENTITY(1,1) NOT NULL', identity[:nullability]
    assert_includes DataRunnerColumnDefinition.query('dbo', "O'Brien"), "N'dbo'"
    assert_includes DataRunnerColumnDefinition.query('dbo', "O'Brien"), "N'O''Brien'"
    assert_nil DataRunnerColumnDefinition.format(
      'name' => 'total', 'type_name' => 'int', 'type_schema' => 'sys',
      'max_length' => 4, 'precision' => 10, 'scale' => 0,
      'is_nullable' => true, 'is_identity' => false, 'is_computed' => true
    )
  end

  test 'treats the SQL22 host names as Kerberos targets' do
    previous = { 'SQL22' => ENV.fetch('SQL22', nil), 'SQL22_HOST' => ENV.fetch('SQL22_HOST', nil) }
    ENV['SQL22'] = '10.1.1.22'
    ENV['SQL22_HOST'] = 'gsa-sql22-tst.example'

    assert MssqlHelpers.kerberos_host?('gsa-sql22-tst.example')
    assert MssqlHelpers.kerberos_host?('10.1.1.22')
    assert_not MssqlHelpers.kerberos_host?('GSASQL16')
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
