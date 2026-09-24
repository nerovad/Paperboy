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

    def invoice(**attributes)
      Aim::Invoice.new(batch_id: '4641.20260814_074337.Invoice-[V20F]', state: 'needs_review', **attributes)
    end

    test 'formats a typed total and a typed date' do
      assert_equal '$1,234.50', aim_currency(BigDecimal('1234.50'))
      assert_equal '08/12/26', aim_invoice_date(Date.new(2026, 8, 12))
    end

    test 'labels a claimant by name and never by email address' do
      named = invoice(claimed_by_name: 'Ryan Hill', claimed_by: 'ryan.hill@vcgsa.org')
      legacy = invoice(claimed_by: 'ryan.hill@vcgsa.org')

      assert_equal 'Ryan Hill', aim_claimant_label(named)
      assert_equal 'Ryan Hill', aim_claimant_label(legacy)
      assert_equal 'Someone', aim_claimant_label(invoice)
    end

    test 'badges an invoice someone else has open with their name' do
      row = invoice(claimed_by: 'ryan.hill@vcgsa.org', claimed_by_name: 'Ryan Hill', claimed_at: Time.current)

      assert_equal ['is-in-review', 'Open by Ryan Hill'], aim_status_badge(row, 'me@vcgsa.org')
    end

    test 'badges an invoice the current user has open' do
      row = invoice(claimed_by: 'me@vcgsa.org', claimed_at: Time.current)

      assert_equal ['is-in-review', 'Open by you'], aim_status_badge(row, 'me@vcgsa.org')
    end

    test 'a lapsed lock is no badge' do
      row = invoice(claimed_by: 'ryan.hill@vcgsa.org', claimed_at: 10.minutes.ago, review_reason: 'unknown_vendor')

      assert_equal ['is-denied', 'Unknown vendor'], aim_status_badge(row, 'me@vcgsa.org')
    end

    test 'badges an unclaimed invoice with why it needs a person, or its state' do
      assert_equal ['is-denied', 'Unknown vendor'], aim_status_badge(invoice(review_reason: 'unknown_vendor'), 'me@vcgsa.org')
      assert_equal ['is-approved', 'Ready for approval'], aim_status_badge(invoice(state: 'ready_for_approval'), 'me@vcgsa.org')
    end

    test 'queues and reasons have labels' do
      assert_equal 'Action Needed', aim_queue_label('needs_review')
      assert_equal 'Handwritten amounts', aim_review_reason_label('handwritten')
      assert_equal 'Vendor Name', aim_field_label('vendor_name')
    end
  end
end
