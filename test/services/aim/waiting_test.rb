# frozen_string_literal: true

require 'test_helper'

module Aim
  # How long invoices have waited where they are (#170), for the age pills and
  # the dashboard's Stale panel.
  class WaitingTest < ActiveSupport::TestCase
    def invoice(batch_id, state: 'needs_review', **attributes)
      Aim::Invoice.create!(batch_id: batch_id, state: state, actor: 'aim_worker', budget_unit: '4601', **attributes)
    end

    def backdate(row, days) = row.events.update_all(created_at: days.days.ago)

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

    test 'the dashboard lists stale invoices by queue and owner, longest first, never finished ones' do
      backdate(invoice('A1', assigned_to: 'Sam Lee', assignment_source: 'test', state: 'ready_for_approval'), 45)
      backdate(invoice('A2', assigned_to: 'Sam Lee', assignment_source: 'test', state: 'ready_for_approval'), 31)
      backdate(invoice('B1', state: 'failed'), 60)
      backdate(invoice('FRESH'), 5)
      backdate(invoice('GONE', state: 'deleted'), 400)

      stale = Aim::DashboardStats.new(Aim::Invoice.all).stale(days: 30)

      assert_equal [['failed', Aim::Invoice::SHARED_QUEUE, 1, 60], ['ready_for_approval', 'Sam Lee', 2, 45]], stale
    end
  end
end
