# frozen_string_literal: true

require 'test_helper'

# Guards the sp_executesql bind-type patch in
# config/initializers/sqlserver_bigint_binds.rb.
#
# activerecord-sqlserver-adapter infers a parameter type from the Ruby value
# whenever a bind carries no attribute type, and its range check guards only
# the positive side, so a value below -2_147_483_648 goes out as `int` and SQL
# Server answers "Error converting data type numeric to int".
#
# Solid Cache reads are built from untyped binds on `key_hash`, a signed 64-bit
# hash, so before the patch roughly half of all cache keys could be written but
# never read back. These assertions fail if the initializer is dropped -- say,
# after an adapter upgrade that turns out not to carry the fix.
class SqlserverBindTypesTest < ActiveSupport::TestCase
  def sql_type_for(value)
    ActiveRecord::Base.connection.send(:sp_executesql_sql_type, value)
  end

  test 'integers outside the 32-bit range bind as bigint in both directions' do
    assert_equal 'bigint', sql_type_for(-7_643_728_979_924_194_314)
    assert_equal 'bigint', sql_type_for(-2_147_483_649)
    assert_equal 'bigint', sql_type_for(2_147_483_648)
    assert_equal 'bigint', sql_type_for(4_975_874_886_716_014_967)
  end

  test 'integers inside the 32-bit range still bind as int' do
    assert_equal 'int', sql_type_for(-2_147_483_648)
    assert_equal 'int', sql_type_for(0)
    assert_equal 'int', sql_type_for(2_147_483_647)
  end

  # The test environment uses :null_store, so this reaches for Solid Cache
  # directly. key_hash is a signed 64-bit hash, giving each key about a 50%
  # chance of landing negative -- the case that used to raise on read. Writes
  # always worked, so only the read side proves anything. Twenty-five keys make
  # a run where none hash negative vanishingly unlikely.
  test 'cache entries read back whatever the sign of their key hash' do
    store = ActiveSupport::Cache.lookup_store(:solid_cache_store)

    25.times do |i|
      key = "sqlserver_bind_types_test_#{i}"
      store.write(key, "value #{i}")
      assert_equal "value #{i}", store.read(key)
    end
  end
end
