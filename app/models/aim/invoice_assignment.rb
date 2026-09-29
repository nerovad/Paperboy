# frozen_string_literal: true

module Aim
  # Whose queue an invoice is in: a person, by GSABSS employee id (the id
  # Emulate picks, so a queue belongs to a real account), or the BU's shared
  # queue when there is none. assigned_to keeps the person's display name.
  # Moving an invoice is not a change of state but is a decision someone made,
  # so it is written as an event. Included by Aim::Invoice.
  module InvoiceAssignment
    extend ActiveSupport::Concern

    SHARED_QUEUE = 'SHARED'

    included do
      scope :owned_by, ->(employee_id) { where(assigned_employee_id: employee_id) }
      # Ready invoices in the shared queues of these BUs (nil: every BU).
      scope :shared_for, lambda { |budget_units|
        scope = in_queue('ready_for_approval').where(assigned_employee_id: nil)
        budget_units.nil? ? scope : scope.where(budget_unit: budget_units)
      }
    end

    class_methods do
      # "First Last" for an employee id, or nil when there is no such person.
      def employee_name(employee_id)
        employee = Employee.find_by(id: employee_id)
        employee && "#{employee.first_name} #{employee.last_name}".squish
      end
    end

    def queue_owner = assigned_to.presence || SHARED_QUEUE

    def shared_queue? = assigned_employee_id.nil? && assigned_to.blank?

    # Move the invoice to a person's queue (an employee id) or to the BU's
    # shared queue (SHARED or blank). Returns the invoice when it moved, nil
    # when it was already there.
    # unit: the budget unit the invoice takes with its new owner, when they do
    # not work in its own (the BU follows the person, 2026-09-29); exception:
    # kept in its own BU anyway, by an AIM Admin or its BU Admin, for this
    # invoice only. Either is named in the history.
    def reassign!(owner, actor:, unit: nil, exception: false)
      raise Aim::Invoice::IllegalTransition, "#{batch_id} is finished and cannot be moved to another queue." if terminal?

      was = queue_owner
      was_unit = budget_unit
      target_id, target_name = resolve_owner(owner)
      unit = unit.presence && unit.to_s != was_unit.to_s ? unit.to_s : nil
      return if target_id == assigned_employee_id && (target_id || shared_queue?) && unit.nil?

      changes = { assigned_employee_id: target_id, assigned_to: target_name, assignment_source: target_id ? 'reassigned' : nil }
      changes.merge!(budget_unit: unit, agency: nil) if unit
      note = "moved from #{was} to #{target_name || "the #{budget_unit} shared queue"}"
      note += ", and its budget unit from #{was_unit} to #{unit}" if unit
      note += ", kept in #{was_unit} by exception" if exception
      transaction do
        update!(changes)
        events.create!(action: 'assignment', from_state: state, to_state: state, actor: actor, note: note)
      end
      forget_rule_coding! if unit
      self
    end

    # Move the invoice to another budget unit's shared queue. That changes its
    # budget unit, which is what billing charges, so the event says so; the
    # billing row takes the new BU when the worker next writes it (decided
    # 2026-09-25). Returns the invoice, or nil when it was already there.
    def move_to_unit!(unit, actor:)
      raise Aim::Invoice::IllegalTransition, "#{batch_id} is finished and cannot be moved to another queue." if terminal?

      target = unit.to_s.strip
      raise ActiveRecord::RecordInvalid.new(self), 'Pick a budget unit.' if target.blank?
      return if target == budget_unit.to_s && shared_queue?

      was_unit = budget_unit
      was = queue_owner
      transaction do
        update!(budget_unit: target, assigned_employee_id: nil, assigned_to: nil, assignment_source: nil)
        events.create!(action: 'assignment', from_state: state, to_state: state, actor: actor,
                       note: "moved from #{was == SHARED_QUEUE ? "the #{was_unit} shared queue" : was} " \
                             "to the #{target} shared queue; budget unit changed from #{was_unit.presence || 'none'} to #{target}")
      end
      self
    end

    private

    def resolve_owner(owner)
      value = owner.to_s.strip
      return [nil, nil] if value.blank? || value.casecmp?(SHARED_QUEUE)

      name = self.class.employee_name(value)
      raise ActiveRecord::RecordInvalid.new(self), "#{value} is not a known person" if name.nil?

      [value.to_i, name]
    end
  end
end
