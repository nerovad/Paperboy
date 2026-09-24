# frozen_string_literal: true

require 'test_helper'

# Guards db/schema.rb against the ways AIM's tables in the aim SQL schema can
# break it.
#
# Every test database -- each parallel worker's, and CI's -- is built by
# loading db/schema.rb, so a line in it that cannot load fails the whole
# suite, for every team. The SQL Server adapter writes two such lines on its
# own when a table is schema-qualified:
#
# - a foreign key on "aim.invoice_events" is dumped as "invoice_events", with
#   its schema dropped, and the load fails looking for a dbo table that does
#   not exist;
# - an index given no name is called index_aim.invoices_on_..., and SQL
#   Server rejects the dot.
#
# Hence AIM's rules: no database foreign keys on aim tables, and every index
# named explicitly. These tests catch either rule being broken before the
# schema reaches anyone's test run.
module Aim
  class SchemaConventionsTest < ActiveSupport::TestCase
    SCHEMA = Rails.root.join('db/schema.rb').read.freeze

    test 'every foreign key names tables the schema creates' do
      tables = SCHEMA.scan(/^\s*create_table "([^"]+)"/).flatten
      dangling = SCHEMA.scan(/^\s*add_foreign_key "([^"]+)", "([^"]+)"/).flatten.uniq - tables

      assert_empty dangling, "db/schema.rb has a foreign key on a table it never creates: #{dangling.join(', ')}"
    end

    test 'the aim schema is created before its tables' do
      schema_at = SCHEMA.index('create_schema "aim"')
      first_table_at = SCHEMA.index('create_table "aim.')

      assert schema_at, 'db/schema.rb does not create the aim schema'
      assert_operator schema_at, :<, first_table_at if first_table_at
    end

    test 'no index name carries a schema dot' do
      dotted = SCHEMA.scan(/name: "([^"]*\.[^"]*)"/).flatten

      assert_empty dotted, "Index names with a dot: #{dotted.join(', ')}"
    end
  end
end
