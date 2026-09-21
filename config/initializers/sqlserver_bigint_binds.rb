# frozen_string_literal: true

# Patches a bind-type bug in activerecord-sqlserver-adapter (8.1.3, the newest
# release as of 2026-09-18).
#
# When a bind carries no attribute type, the adapter infers the sp_executesql
# parameter type from the Ruby value, and the range check only guards the
# positive side:
#
#   (value > 2_147_483_647) ? "bigint" : "int"
#
# Anything below -2_147_483_648 is therefore declared `int`, and SQL Server
# rejects the statement with "Error converting data type numeric to int".
#
# Solid Cache reads land exactly there: the entry lookup is built with untyped
# binds and `key_hash` is a signed 64-bit hash, so roughly half of all cache
# keys hash negative and every read of one raised. Writes were unaffected --
# they bind through typed model attributes -- so the cache filled up normally
# and only reads failed, which is why it looked healthy from the outside.
#
# Delete this file once the adapter ships its own fix.
module SqlServerBigintBinds
  INT_RANGE = (-2_147_483_648..2_147_483_647)

  private

  def sp_executesql_sql_type(attr)
    type = super
    return type unless type == 'int'

    value = active_model_attribute?(attr) ? attr.value_for_database : attr
    return type unless value.is_a?(Integer) && !INT_RANGE.cover?(value)

    'bigint'
  end
end

ActiveSupport.on_load(:active_record) do
  require 'active_record/connection_adapters/sqlserver_adapter'
  ActiveRecord::ConnectionAdapters::SQLServerAdapter.prepend(SqlServerBigintBinds)
end
