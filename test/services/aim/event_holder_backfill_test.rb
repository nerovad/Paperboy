# frozen_string_literal: true

require 'test_helper'

module Aim
  # Older events learn who held the invoice after them from its history
  # (#190): walked back from today's holder through the assignment notes.
  class EventHolderBackfillTest < ActiveSupport::TestCase
    def invoice(batch_id, **attributes)
      Aim::Invoice.create!(batch_id: batch_id, state: 'ready_for_approval', document_type: 'Invoice',
                           budget_unit: '4601', actor: 'aim_worker', **attributes)
    end

    # An event as it was written before #190: no holder.
    def old_event(row, days_ago, **attributes)
      event = row.events.create!(actor: 'x', created_at: days_ago.days.ago, **attributes)
      Aim::InvoiceEvent.where(id: event.id).update_all(holder_employee_id: nil, holder_name: nil,
                                                       holder_budget_unit: nil, holder_source: nil)
      event
    end

    def holder(event) = event.reload.slice(:holder_employee_id, :holder_name, :holder_budget_unit, :holder_source).values

    test 'a history is walked back from the holder today through each move' do
      invoice('OTHER', assigned_employee_id: 5, assigned_to: 'Sam Lee', assignment_source: 'test')
      row = invoice('WALKED', assigned_employee_id: 8, assigned_to: 'Pat Kim', assignment_source: 'test', budget_unit: '4602')
      Aim::InvoiceEvent.where(invoice_id: row.id).delete_all
      arrived = old_event(row, 5, action: 'transition', to_state: 'received')
      to_sam = old_event(row, 4, action: 'assignment', note: 'moved from SHARED to Sam Lee')
      ready = old_event(row, 3, action: 'transition', from_state: 'received', to_state: 'ready_for_approval')
      to_pat = old_event(row, 2, action: 'assignment', note: 'moved from Sam Lee to Pat Kim, and its budget unit from 4601 to 4602')

      result = Aim::EventHolderBackfill.new.call

      assert_equal [8, 'Pat Kim', '4602', 'inferred'], holder(to_pat)
      assert_equal [5, 'Sam Lee', '4601', 'inferred'], holder(ready)
      assert_equal [5, 'Sam Lee', '4601', 'inferred'], holder(to_sam)
      assert_equal [nil, nil, '4601', 'inferred'], holder(arrived), 'before Sam it was in the shared queue'
      assert_equal 4, result.inferred
      assert_equal 0, result.unknown
    end

    test 'an invoice owned by name alone takes the id that name has elsewhere' do
      invoice('OTHER', assigned_employee_id: 5, assigned_to: 'Sam Lee', assignment_source: 'test')
      row = invoice('NAMED', assigned_to: 'Sam Lee', assignment_source: 'test')
      Aim::InvoiceEvent.where(invoice_id: row.id).delete_all
      event = old_event(row, 1, action: 'transition', to_state: 'ready_for_approval')

      Aim::EventHolderBackfill.new.call

      assert_equal [5, 'Sam Lee', '4601', 'inferred'], holder(event)
    end

    test 'a move to another shared queue steps back to the unit it left' do
      row = invoice('UNIT', budget_unit: '4602')
      Aim::InvoiceEvent.where(invoice_id: row.id).delete_all
      first = old_event(row, 3, action: 'transition', to_state: 'ready_for_approval')
      moved = old_event(row, 1, action: 'assignment',
                                note: 'moved from the 4601 shared queue to the 4602 shared queue; budget unit changed from 4601 to 4602')

      Aim::EventHolderBackfill.new.call

      assert_equal [nil, nil, '4602', 'inferred'], holder(moved)
      assert_equal [nil, nil, '4601', 'inferred'], holder(first)
    end

    test 'where the history does not add up, that event and everything older stay unknown' do
      row = invoice('GAP', assigned_employee_id: 9, assigned_to: 'Lee Ray', assignment_source: 'test')
      Aim::InvoiceEvent.where(invoice_id: row.id).delete_all
      first = old_event(row, 4, action: 'transition', to_state: 'ready_for_approval')
      gap = old_event(row, 3, action: 'assignment', note: 'moved from SHARED to Sam Lee')
      latest = old_event(row, 1, action: 'approval', note: 'first approval')

      result = Aim::EventHolderBackfill.new.call

      assert_equal [9, 'Lee Ray', '4601', 'inferred'], holder(latest)
      assert_equal [nil, nil, nil, nil], holder(gap), 'it says Sam Lee, but Lee Ray held it next: a move went unrecorded'
      assert_equal [nil, nil, nil, nil], holder(first)
      assert_equal [1, 2], [result.inferred, result.unknown]
    end

    test 'a second run changes nothing, and recorded events are never touched' do
      row = invoice('TWICE', assigned_employee_id: 5, assigned_to: 'Sam Lee', assignment_source: 'test')
      recorded = row.events.sole
      old_event(row, 2, action: 'manual_entry')

      Aim::EventHolderBackfill.new.call
      again = Aim::EventHolderBackfill.new.call

      assert_equal [0, 0, 0], [again.invoices, again.inferred, again.unknown]
      assert_equal 'recorded', recorded.reload.holder_source
    end
  end
end
