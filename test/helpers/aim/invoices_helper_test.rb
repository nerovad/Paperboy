# frozen_string_literal: true

require 'test_helper'

module Aim
  class InvoicesHelperTest < ActionView::TestCase
    tests Aim::InvoicesHelper

    self.fixture_table_names = []

    test 'formats numeric totals as currency and leaves everything else alone' do
      assert_equal '$250.00', aim_currency('250.00')
      assert_equal '$20,341.00', aim_currency('20341.00')
      assert_equal '$5,971.18', aim_currency('$5,971.18')
      assert_equal 'N/A', aim_currency('N/A')
      assert_nil aim_currency(nil)
    end

    test 'formats a credit with a leading minus' do
      assert_equal '-$14.88', aim_currency('-14.88')
    end

    test 'reads numeric invoice dates month first' do
      # Date.parse would call this the eighth of December.
      assert_equal '08/12/26', aim_invoice_date('8/12/2026')
      assert_equal '08/12/26', aim_invoice_date('08/12/2026')
      assert_equal '08/12/26', aim_invoice_date('8/12/26')
      assert_equal '08/12/26', aim_invoice_date('8-12-2026')
    end

    test 'formats non numeric dates and passes unparseable ones through' do
      assert_equal '08/12/26', aim_invoice_date('2026-08-12')
      assert_equal '08/12/26', aim_invoice_date('August 12, 2026')
      assert_equal '13/45/2026', aim_invoice_date('13/45/2026')
      assert_equal 'not a date', aim_invoice_date('not a date')
      assert_nil aim_invoice_date(nil)
    end

    test 'prefers the extracted invoice number as the row reference' do
      invoice = { metadata: { 'InvoiceNumber' => '12286377' },
                  name: '4641.20260814_074337.Invoice-[V20F]' }

      assert_equal '12286377', aim_invoice_reference(invoice)
    end

    test 'reports a missing invoice number rather than substituting an identifier' do
      # The folder's "-[V20F]" code is not an invoice number and reads exactly
      # like one, so it must never be shown in this column.
      invoice = { metadata: {}, name: '4641.20260814_074337.Invoice-[V20F]' }

      assert_nil aim_invoice_reference(invoice)
    end

    test 'labels a claimant by name and never by email address' do
      named = { claimed_by_name: 'Ryan Hill', claimed_by: 'ryan.hill@vcgsa.org' }
      legacy = { claimed_by: 'ryan.hill@vcgsa.org' }

      assert_equal 'Ryan Hill', aim_claimant_label(named)
      assert_equal 'Ryan Hill', aim_claimant_label(legacy)
      assert_equal 'Someone', aim_claimant_label({})
    end

    test 'badges an invoice claimed by someone else with their name' do
      invoice = { claimed_by: 'ryan.hill@vcgsa.org', claimed_by_name: 'Ryan Hill', metadata: {} }

      assert_equal ['is-in-review', 'Claimed by Ryan Hill'], aim_status_badge(invoice, 'me@vcgsa.org')
    end

    test 'badges the current user as the claimant' do
      invoice = { claimed_by: 'me@vcgsa.org', metadata: {} }

      assert_equal ['is-in-review', 'Claimed by You'], aim_status_badge(invoice, 'me@vcgsa.org')
    end

    test 'badges an unclaimed invoice with its pipeline status' do
      invoice = { metadata: { 'Status' => 'Vendor Review' } }

      assert_equal ['is-approved', 'Vendor Review'], aim_status_badge(invoice, 'me@vcgsa.org')
    end
  end
end
