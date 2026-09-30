# frozen_string_literal: true

require 'test_helper'

module Aim
  # Moving an invoice between people is Paperboy's reassignment
  # (Reassignable): a TaskReassignment row and an audited assignee, plus AIM's
  # own event and display name. So the away sweep and routing to cover
  # (AwayPeriod) reach invoices as they reach forms.
  class InvoiceReassignmentTest < ActiveSupport::TestCase
    setup do
      @one, @two = Employee.order(:id).limit(2).to_a
      skip('needs two employees to test with') unless @two
      Current.user = nil
    end

    teardown { Current.reset }

    def invoice(**attributes)
      Aim::Invoice.create!(batch_id: "4601_#{SecureRandom.hex(4)}", state: 'ready_for_approval', document_type: 'Invoice',
                           budget_unit: '4601', actor: 'aim_worker', **attributes)
    end

    def owned_by(employee, **attributes)
      invoice(assigned_employee_id: employee.id, assigned_to: employee.full_name, assignment_source: 'upload', **attributes)
    end

    def members(*ids, &block)
      Aim::Users.stub(:member?, ->(id) { ids.map(&:to_s).include?(id.to_s) }, &block)
    end

    test 'an invoice is one of the models Paperboy can reassign and sweep' do
      assert_includes Aim::Invoice.ancestors, Reassignable
      assert_equal 'assigned_employee_id', Aim::Invoice.new.assignment_field_name
      assert_includes AwayReassignment.reassignable_models, Aim::Invoice
    end

    test 'moving from one person to another leaves a reassignment and an audited assignee' do
      row = owned_by(@one)

      row.reassign!(@two.id, actor: 'staff@example.com', by: 99)

      handover = row.task_reassignments.sole
      assert_equal [@one.id.to_s, @two.id.to_s, '99'],
                   [handover.from_employee_id, handover.to_employee_id, handover.reassigned_by_id]
      assert_equal "moved from #{@one.full_name} to #{@two.full_name}", handover.reason
      assert_equal [@two.id, @two.full_name], [row.reload.assigned_employee_id, row.assigned_to]
      edits = RecordEdit.for_row(row).pluck(:column_name, :old_value, :new_value)
      assert_includes edits, ['assigned_employee_id', @one.id.to_s, @two.id.to_s]
      assert_includes edits, ['assigned_to', @one.full_name, @two.full_name]
      assert_equal %w[assignment staff@example.com], [row.events.last.action, row.events.last.actor]
    end

    test 'from a shared queue there is nobody to reassign from, so only the trail and the event say so' do
      row = invoice

      row.reassign!(@one.id, actor: 'staff@example.com')

      assert_empty row.task_reassignments
      assert_includes RecordEdit.for_row(row).pluck(:column_name, :old_value, :new_value),
                      ['assigned_employee_id', nil, @one.id.to_s]
    end

    test 'Reassignable\'s own entry point makes the same AIM move' do
      row = owned_by(@one)

      handover = members(@two.id) { row.reassign_to!(new_assignee_id: @two.id, reassigned_by_id: @one.id, reason: 'cover') }

      assert_equal row.task_reassignments.sole, handover
      assert_equal [@two.id, @two.full_name, 'reassigned'],
                   [row.reload.assigned_employee_id, row.assigned_to, row.assignment_source]
      assert_equal 'aim', row.events.last.actor, 'nobody signed in: the history names AIM'
      assert_match(/; cover\z/, row.events.last.note)
      assert_equal 'aim', RecordEdit.for_row(row).where(column_name: 'assigned_to').pick(:changed_by_name)
    end

    test 'Reassignable\'s entry point refuses someone who does not work AIM, and a finished invoice' do
      row = owned_by(@one)
      assert_raises(ActiveRecord::RecordInvalid) do
        members { row.reassign_to!(new_assignee_id: @two.id, reassigned_by_id: @one.id) }
      end

      done = owned_by(@one, state: 'exported')
      assert_raises(Aim::Invoice::IllegalTransition) do
        members(@two.id) { done.reassign_to!(new_assignee_id: @two.id, reassigned_by_id: @one.id) }
      end
      assert_equal @one.id, row.reload.assigned_employee_id
    end

    test 'the away sweep hands an away person\'s open invoices to their delegate' do
      period = AwayPeriod.create!(employee_id: @one.id.to_s, delegate_id: @two.id.to_s,
                                  starts_on: Date.current, ends_on: 1.week.from_now.to_date)
      open = owned_by(@one)
      done = owned_by(@one, state: 'exported')

      members(@two.id) { AwayReassignment.new(period).call }

      assert_equal @two.id, open.reload.assigned_employee_id
      assert_equal @two.full_name, open.assigned_to
      assert_match(/Automatically reassigned/, open.task_reassignments.sole.reason)
      assert_equal @one.id, done.reload.assigned_employee_id
    end

    test 'an invoice reaching someone away goes to whoever covers for them' do
      AwayPeriod.create!(employee_id: @one.id.to_s, delegate_id: @two.id.to_s,
                         starts_on: Date.current, ends_on: 1.week.from_now.to_date)
      row = owned_by(@one)

      members(@two.id) { row.hand_to_cover!(by: 99) }

      assert_equal @two.id, row.reload.assigned_employee_id
      assert_equal "#{@one.full_name} is away", row.task_reassignments.sole.reason
    end

    test 'an owner who is here, or whose cover does not work AIM, keeps the invoice' do
      here = owned_by(@one)
      assert_nil(members(@two.id) { here.hand_to_cover! })

      AwayPeriod.create!(employee_id: @one.id.to_s, delegate_id: @two.id.to_s,
                         starts_on: Date.current, ends_on: 1.week.from_now.to_date)
      assert_nil(members { here.hand_to_cover! })
      assert_equal @one.id, here.reload.assigned_employee_id
    end
  end
end
