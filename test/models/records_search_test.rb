# frozen_string_literal: true

require 'test_helper'

class RecordsSearchTest < ActiveSupport::TestCase
  def pcard_table = RegistryTable.find('pcard')

  test 'searches only real text columns' do
    columns = RecordsSearch.searchable_columns(pcard_table)

    assert_includes columns, 'last_name'
    assert_includes columns, 'agency'
  end

  test 'skips encrypted columns' do
    # card_number is encrypted, so the stored ciphertext can never match a
    # plaintext query — including it would be a silently useless comparison.
    assert_not_includes RecordsSearch.searchable_columns(pcard_table), 'card_number'
  end

  test 'skips derived columns that have no SQL counterpart' do
    # masked_card_number is a method, not a column; matching it would raise.
    assert_not_includes RecordsSearch.searchable_columns(pcard_table), 'masked_card_number'
  end

  test 'skips non-text columns' do
    columns = RecordsSearch.searchable_columns(pcard_table)

    assert_not_includes columns, 'issued_date'
    assert_not_includes columns, 'monthly_limit'
  end

  test 'a blank query leaves the scope untouched' do
    table = pcard_table
    base = table.scope

    assert_equal base.to_sql, RecordsSearch.apply(table, base, '   ').to_sql
    assert_equal base.to_sql, RecordsSearch.apply(table, base, nil).to_sql
  end

  test 'a query ORs a LIKE across every searchable column' do
    table = pcard_table
    sql = RecordsSearch.apply(table, table.scope, 'smith').to_sql

    assert_equal RecordsSearch.searchable_columns(table).size, sql.scan('LIKE').size
  end

  test 'quotes are bound, not interpolated' do
    table = pcard_table
    sql = RecordsSearch.apply(table, table.scope, "o'brien").to_sql

    assert_includes sql, "o''brien"
  end

  test 'search composes with a table that narrows its own scope' do
    # The OSHA 300 Log is only the approved reports; searching it must not
    # widen the table back out to drafts and denials.
    table = RegistryTable.find('osha-300-log')

    assert_includes RecordsSearch.apply(table, table.scope, 'ladder').to_sql, 'approved'
  end
end
