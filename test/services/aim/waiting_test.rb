# frozen_string_literal: true

require 'test_helper'

module Aim
  # How long invoices have waited (#170), on two clocks (#190): age, which
  # decides stale, and how long where they are now.
  class WaitingTest < ActiveSupport::TestCase
    def invoice(batch_id, state: 'needs_review', **attributes)
      Aim::Invoice.create!(batch_id: batch_id, state: state, actor: 'aim_worker', budget_unit: '4601', **attributes)
    end

    def backdate(row, days) = row.events.update_all(created_at: days.days.ago)

    def age(row, days)
      row.update_columns(created_at: days.days.ago)
      backdate(row, days)
      row
    end

    test 'an invoice waits from when it reached its state, or changed hands since, or else arrived' do
      reached = invoice('REACHED')
      backdate(reached, 10)
      handed = invoice('HANDED')
      backdate(handed, 20)
      handed.events.create!(action: 'assignment', actor: 'x', created_at: 3.days.ago)
      no_history = invoice('NONE')
      Aim::InvoiceEvent.where(invoice_id: no_history.id).delete_all
      no_history.update_columns(created_at: 40.days.ago)
      done = invoice('DONE', state: 'deleted')

      since = Aim::Waiting.since(Aim::Invoice.all)

      assert_equal 10, Aim::Waiting.days(since[reached.id])
      assert_equal 3, Aim::Waiting.days(since[handed.id])
      assert_equal 40, Aim::Waiting.days(since[no_history.id])
      assert_not since.key?(done.id), 'a finished invoice is not waiting'
    end

    test 'an invoice is as old as when it arrived; a split piece as old as the PDF it came from' do
      parent = age(invoice('PARENT', state: 'split'), 20)
      piece = invoice('PIECE', parent_id: parent.id)
      handed = age(invoice('HANDED'), 12)
      handed.events.create!(action: 'assignment', actor: 'x', created_at: 1.day.ago)
      done = invoice('DONE', state: 'deleted')

      arrived = Aim::Waiting.arrived(Aim::Invoice.all)

      assert_equal 20, Aim::Waiting.days(arrived[piece.id])
      assert_equal 12, Aim::Waiting.days(arrived[handed.id]), 'a hand-off does not make it younger'
      assert_not arrived.key?(done.id)
      assert_not arrived.key?(parent.id), 'a split PDF is finished'
    end

    test 'stale is 30 days unless AIM_STALE_DAYS says otherwise' do
      old = ENV.fetch('AIM_STALE_DAYS', nil)
      ENV.delete('AIM_STALE_DAYS')
      assert_equal 30, Aim::Waiting.stale_days
      ENV['AIM_STALE_DAYS'] = '14'
      assert_equal 14, Aim::Waiting.stale_days
      ENV['AIM_STALE_DAYS'] = 'soon'
      assert_equal 30, Aim::Waiting.stale_days
    ensure
      old.nil? ? ENV.delete('AIM_STALE_DAYS') : ENV['AIM_STALE_DAYS'] = old
    end

    test 'the dashboard lists stale invoices by queue and owner, oldest first, never finished ones' do
      age(invoice('A1', assigned_to: 'Sam Lee', assignment_source: 'test', state: 'ready_for_approval'), 45)
      age(invoice('A2', assigned_to: 'Sam Lee', assignment_source: 'test', state: 'ready_for_approval'), 31)
      age(invoice('B1', state: 'failed'), 60)
      age(invoice('FRESH'), 5)
      age(invoice('GONE', state: 'deleted'), 400)

      stale = Aim::DashboardStats.new(Aim::Invoice.all).stale(days: 30)

      assert_equal [['failed', Aim::Invoice::SHARED_QUEUE, 1, 60], ['ready_for_approval', 'Sam Lee', 2, 45]], stale
    end

    test 'an old invoice handed on just now is still stale, charged to whoever holds it now' do
      passed = age(invoice('PASSED', assigned_to: 'Pat Kim', assignment_source: 'test', state: 'ready_for_approval'), 35)
      passed.events.create!(action: 'assignment', actor: 'x', created_at: 1.hour.ago)

      stats = Aim::DashboardStats.new(Aim::Invoice.all)

      assert_equal [['ready_for_approval', 'Pat Kim', 1, 35]], stats.stale(days: 30)
      assert_equal [[passed, 35, 0]], stats.oldest('ready_for_approval')
    end
  end
end
