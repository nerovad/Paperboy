# frozen_string_literal: true

require 'test_helper'

module Aim
  # Every event records who held the invoice after it (#190), whatever wrote
  # it: a state change, a move between people or queues, or anything else.
  class InvoiceEventHolderTest < ActiveSupport::TestCase
    setup { Current.user = nil }
    teardown { Current.reset }

    def invoice(**attributes)
      Aim::Invoice.create!(batch_id: "4601_#{SecureRandom.hex(4)}", state: 'ready_for_approval', document_type: 'Invoice',
                           budget_unit: '4601', actor: 'aim_worker', **attributes)
    end

    def holder(event) = event.slice(:holder_employee_id, :holder_name, :holder_budget_unit, :holder_source).values

    test 'the first event and a change of state record the holder, by the invoice as it is after' do
      row = invoice(assigned_employee_id: 5, assigned_to: 'Sam Lee', assignment_source: 'upload')

      row.transition_to!('needs_review', actor: 'staff@example.com', note: 'sent back')

      created, moved = row.events.order(:id).to_a
      assert_equal [5, 'Sam Lee', '4601', 'recorded'], holder(created)
      assert_equal [5, 'Sam Lee', '4601', 'recorded'], holder(moved)
    end

    test 'a shared queue is recorded as nobody, in its budget unit' do
      row = invoice

      assert_equal [nil, nil, '4601', 'recorded'], holder(row.events.sole)
    end

    test 'moving to another budget unit records the new unit' do
      row = invoice

      row.move_to_unit!('4602', actor: 'staff@example.com')

      assert_equal [nil, nil, '4602', 'recorded'], holder(row.events.where(action: 'assignment').sole)
    end

    test 'moving to a person records them, and moving back to the shared queue records nobody' do
      one = Employee.order(:id).first || skip('needs an employee to test with')
      row = invoice

      row.reassign!(one.id, actor: 'staff@example.com', by: 99)
      row.reassign!('SHARED', actor: 'staff@example.com', by: 99)

      to_person, to_shared = row.events.where(action: 'assignment').order(:id).to_a
      assert_equal [one.id, one.full_name, '4601', 'recorded'], holder(to_person)
      assert_equal [nil, nil, '4601', 'recorded'], holder(to_shared)
    end

    test 'an event that moves nothing still says who held it' do
      row = invoice(assigned_employee_id: 5, assigned_to: 'Sam Lee', assignment_source: 'upload')

      row.flag_manual_entry!(actor: 'staff@example.com')

      assert_equal [5, 'Sam Lee', '4601', 'recorded'], holder(row.events.where(action: 'manual_entry').sole)
    end

    test 'a holder given outright is kept' do
      row = invoice

      event = row.events.create!(action: 'assignment', actor: 'x', holder_name: 'Pat Kim', holder_source: 'inferred')

      assert_equal [nil, 'Pat Kim', nil, 'inferred'], holder(event)
    end
  end
end
