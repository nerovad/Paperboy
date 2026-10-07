# frozen_string_literal: true

require 'test_helper'
require_relative '../support/records_email_helpers'

class RecordsEmailRuleTest < ActiveSupport::TestCase
  include RecordsEmailHelpers

  test 'matches the rows a highlight rule with the same condition would shade' do
    stale = vehicle('V1', 'GSA', pacific(2025, 1, 1, 12))
    vehicle('V2', 'GSA', pacific(2026, 1, 1, 12))

    assert_equal [stale], email_rule.matching_rows
    assert_equal 'Last Updated is on or before 12/15/2025', email_rule.description
  end

  test 'a rule that does not split needs recipients, and they must be county employees' do
    with_county_employees('fleet@ventura.org') do
      assert email_rule(split_column: nil, recipients: 'Fleet@ventura.org').valid?
      assert_not email_rule(split_column: nil, recipients: '').valid?
      assert_not email_rule(split_column: nil, recipients: 'fleet@ventura.org, someone@gmail.com').valid?
      assert email_rule.valid?
    end
  end

  test 'validates the split column, the name and the message' do
    assert_not email_rule(split_column: 'nope').valid?
    assert_not email_rule(label: '').valid?
    assert_not email_rule(message: '').valid?
    assert_not email_rule(column_name: 'make', operator: 'before').valid?
  end

  test "each value's contacts get only that value's rows; the rest go to the owner" do
    gsa = [vehicle('V1', 'GSA', pacific(2025, 1, 1, 12)), vehicle('V2', 'gsa ', pacific(2025, 1, 2, 12))]
    hca = vehicle('V3', 'HCA', pacific(2025, 1, 3, 12))
    ita = vehicle('V4', 'ITA', pacific(2025, 1, 4, 12))

    with_county_employees('gsa@ventura.org', 'gone@ventura.org') do
      RecordsEmailContact.create!(table_slug: 'fleet', column_name: 'agency', match_value: 'GSA',
                                  email: 'gsa@ventura.org')
      # Listed while employed, since left: skipped at send time.
      RecordsEmailContact.create!(table_slug: 'fleet', column_name: 'agency', match_value: 'HCA',
                                  email: 'gone@ventura.org')
    end

    batches = with_county_employees('gsa@ventura.org') do
      email_rule.batches(gsa + [hca, ita], owner_email: 'owner@ventura.org')
    end

    assert_equal 2, batches.size
    assert_equal [['gsa@ventura.org'], gsa, 'GSA'], batches.first.to_a.first(3)
    assert_equal ['owner@ventura.org'], batches.last.to
    assert_equal [hca, ita], batches.last.rows
    assert_equal %w[HCA ITA], batches.last.unrouted
  end

  test 'a rule that does not split sends every row to its recipients' do
    rows = [vehicle('V1', 'GSA', pacific(2025, 1, 1, 12)), vehicle('V2', 'HCA', pacific(2025, 1, 2, 12))]
    rule = email_rule(split_column: nil, recipients: 'a@ventura.org; b@ventura.org')

    batches = with_county_employees('a@ventura.org', 'b@ventura.org') do
      rule.batches(rows, owner_email: 'owner@ventura.org')
    end

    assert_equal 1, batches.size
    assert_equal %w[a@ventura.org b@ventura.org], batches.first.to
    assert_equal rows, batches.first.rows
    assert_nil batches.first.group
  end

  test 'a contact must be a county employee and is listed once per value' do
    attrs = { table_slug: 'fleet', column_name: 'agency', match_value: ' GSA ', email: ' GSA@Ventura.org ' }

    with_county_employees('gsa@ventura.org') do
      contact = RecordsEmailContact.create!(attrs)

      assert_equal %w[GSA gsa@ventura.org], [contact.match_value, contact.email]
      assert_not RecordsEmailContact.new(attrs).valid?
      assert_not RecordsEmailContact.new(attrs.merge(email: 'someone@gmail.com')).valid?
      assert_not RecordsEmailContact.new(attrs.merge(column_name: 'nope')).valid?
    end
  end
end
