# frozen_string_literal: true

require 'English'
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

  test 'treats SQL22_HOST as the Kerberos target' do
    previous = ENV.fetch('SQL22_HOST', nil)
    ENV['SQL22_HOST'] = 'gsa-sql22-tst.example'

    assert MssqlHelpers.kerberos_host?('gsa-sql22-tst.example')
    assert_not MssqlHelpers.kerberos_host?('10.1.1.22')
    assert_not MssqlHelpers.kerberos_host?('GSASQL16')
  ensure
    previous.nil? ? ENV.delete('SQL22_HOST') : ENV['SQL22_HOST'] = previous
  end

  test 'selects a database without ActiveSupport' do
    helper = Rails.root.join('script/ruby/data_runner/db/mssql_helpers.rb')
    script = <<~RUBY
      require #{helper.to_s.inspect}
      ENV['MSSQL_DATABASE'] = 'Paperboy'
      ENV['GSABSS_DATABASE'] = ''
      fallback = MssqlHelpers.selected_database('', false)
      raise "fallback \#{fallback.inspect}" unless fallback == 'Paperboy'
      raise 'kerberos' unless MssqlHelpers.selected_database(nil, true).nil?
      raise 'explicit' unless MssqlHelpers.selected_database('GSARecords', false) == 'GSARecords'
      ENV['MSSQL_DATABASE'] = '   '
      ENV['GSABSS_DATABASE'] = ''
      raise 'blank' unless MssqlHelpers.selected_database('', false).nil?
    RUBY
    output = IO.popen([RbConfig.ruby, '-e', script], err: %i[child out], &:read)

    assert $CHILD_STATUS.success?, output
  end
end
