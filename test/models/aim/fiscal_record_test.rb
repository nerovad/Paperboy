# frozen_string_literal: true

require 'test_helper'

module Aim
  # What Fiscal records beside an approved invoice (item f).
  class FiscalRecordTest < ActiveSupport::TestCase
    def invoice(batch_id, state, **attrs)
      Aim::Invoice.create!(batch_id: batch_id, state: state, actor: 'test', **attrs)
    end

    test 'every approved invoice is taken in once, and nothing earlier' do
      approved = invoice('F-1', 'approved')
      exported = invoice('F-2', 'exported')
      invoice('F-3', 'ready_for_approval', document_type: 'Invoice')

      assert_equal 2, Aim::FiscalRecord.take_in_approved!
      assert_equal 0, Aim::FiscalRecord.take_in_approved!
      assert_equal [approved.id, exported.id].sort, Aim::FiscalRecord.pluck(:invoice_id).sort
      assert_equal %w[review review], Aim::FiscalRecord.pluck(:status)
    end

    test 'a move writes the history and refuses a move Fiscal does not make' do
      record = Aim::FiscalRecord.create!(invoice: invoice('F-4', 'approved'))

      record.move_to!('on_hold', actor: 'fiscal@example.com', note: 'reason: no MA', hold_reason: 'no MA')

      assert_equal 'on_hold', record.reload.status
      assert_equal 'fiscal@example.com', record.updated_by
      event = record.invoice.events.last
      assert_equal 'fiscal', event.action
      assert_equal 'Fiscal: Fiscal Queue → On Hold — reason: no MA', event.note
      assert_raises(ArgumentError) { record.move_to!('archived', actor: 'fiscal@example.com') }
      assert_equal 'on_hold', record.reload.status
    end

    test 'the title is DocuShare\'s, #INV unless tagged' do
      acme = invoice('F-5', 'approved', budget_unit: '4641', vendor_name: 'ACME', invoice_number: 'A-9',
                                        invoice_date: Date.new(2026, 9, 3))
      record = Aim::FiscalRecord.create!(invoice: acme)

      assert_equal '#INV_4641_ACME_A-9_20260903', record.title
      record.update!(tag: 'HOLD PMT')
      assert_equal 'HOLD PMT_4641_ACME_A-9_20260903', record.title
    end

    test 'the counts are keyed as the sidebar keys them' do
      Aim::FiscalRecord.create!(invoice: invoice('F-6', 'approved'), status: 'ready')

      counts = Aim::FiscalRecord.status_counts
      assert_equal 1, counts['fiscal_ready']
      assert_equal 0, counts['fiscal_review']
    end

    test 'Fiscal shows among a person\'s roles' do
      Aim::Member.create!(employee_id: 91, fiscal: true)

      assert_equal %w[User Fiscal], Aim::Users.roles_of(91)
    end

    test 'a tag must be one of DocuShare\'s' do
      record = Aim::FiscalRecord.new(invoice: invoice('F-7', 'approved'), tag: 'made up')

      assert_not record.valid?
    end
  end
end
