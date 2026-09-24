# frozen_string_literal: true

require 'test_helper'

module Aim
  class InvoiceTest < ActiveSupport::TestCase
    def build(**attributes)
      Aim::Invoice.new(batch_id: "4601_#{SecureRandom.hex(4)}", state: 'received', actor: 'watcher', **attributes)
    end

    test 'reads its table from the aim schema' do
      assert_equal 'aim.invoices', Aim::Invoice.table_name
    end

    test 'is valid with a batch id and a state' do
      assert_predicate build, :valid?
    end

    test 'requires a batch id and a state' do
      invoice = Aim::Invoice.new

      assert_not invoice.valid?
      assert_includes invoice.errors[:batch_id], "can't be blank"
      assert_includes invoice.errors[:state], "can't be blank"
    end

    test 'refuses a second row for the same batch id' do
      first = build.tap(&:save!)
      second = build(batch_id: first.batch_id)

      assert_not second.valid?
      assert_includes second.errors[:batch_id], 'has already been taken'
    end

    test 'the database refuses a duplicate batch id the model never saw' do
      first = build.tap(&:save!)

      assert_raises(ActiveRecord::RecordNotUnique) do
        Aim::Invoice.insert_all!([{ batch_id: first.batch_id, state: 'received' }])
      end
    end

    test 'budget unit is a four-digit code' do
      assert_predicate build(budget_unit: '0000'), :valid?
      assert_predicate build(budget_unit: '4601'), :valid?
      assert_not build(budget_unit: '460').valid?
      assert_not build(budget_unit: '46O1').valid?
    end

    test 'a claim records when it was made' do
      assert_not build(claimed_by: 'someone@example.test').valid?
      assert_predicate build(claimed_by: 'someone@example.test', claimed_at: Time.current), :valid?
    end

    test 'an assignment records how it was made' do
      assert_not build(assigned_to: 'someone@example.test').valid?
      assert_predicate build(assigned_to: 'someone@example.test', assignment_source: 'manual'), :valid?
    end

    test 'money and dates come back typed' do
      invoice = build(invoice_total: '-1234.50', invoice_date: '2026-09-21').tap(&:save!).reload

      assert_equal BigDecimal('-1234.50'), invoice.invoice_total
      assert_equal Date.new(2026, 9, 21), invoice.invoice_date
    end

    test 'key fields keep their punctuation' do
      invoice = build(vendor_name: 'AT&T MOBILITY', invoice_number: 'INV-2024/001').tap(&:save!).reload

      assert_equal 'AT&T MOBILITY', invoice.vendor_name
      assert_equal 'INV-2024/001', invoice.invoice_number
    end
  end
end
