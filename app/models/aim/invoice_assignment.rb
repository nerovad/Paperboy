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

    include Reassignable

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
        employee&.full_name
      end
    end

    # Where Reassignable, and so the away sweep, finds the assignee.
    def assignment_field_name = 'assigned_employee_id'

    def queue_owner = assigned_to.presence || SHARED_QUEUE

    def shared_queue? = assigned_employee_id.nil? && assigned_to.blank?

    # Move the invoice to a person's queue (an employee id) or to the BU's
    # shared queue (SHARED or blank). Returns the invoice when it moved, nil
    # when it was already there.
    # unit: the budget unit the invoice takes with its new owner, when they do
    # not work in its own (the BU follows the person, 2026-09-29); exception:
    # kept in its own BU anyway, by an AIM Admin or its BU Admin, for this
    # invoice only. Either is named in the history.
    # by: the mover's employee id, for Paperboy's reassignment history
    # (defaults to the signed-in person).
    #
    # From one person to another this is Paperboy's reassignment
    # (Reassignable#reassign_to!): a TaskReassignment row, which Take Back and
    # the away sweep rely on, and the audited assignee. To or from a shared
    # queue there is nobody on one side, which a TaskReassignment cannot say,
    # so only the audited columns and the event record it.
    def reassign!(owner, actor:, unit: nil, exception: false, by: nil)
      refuse_if_finished!
      target_id, target_name = resolve_owner(owner)
      unit = unit.presence && unit.to_s != budget_unit.to_s ? unit.to_s : nil
      return if target_id == assigned_employee_id && (target_id || shared_queue?) && unit.nil?

      move_owner!(target_id, target_name, actor: actor, by: by, unit: unit, exception: exception)
    end

    # Reassignable's entry point, which Paperboy's inbox Reassign and Take Back
    # and the away sweep (AwayReassignment) call: the same move as #reassign!,
    # to a person who works AIM, keeping the invoice in its budget unit. The
    # history names the signed-in person, or AIM when nobody is (the sweep).
    # Returns the TaskReassignment, or nil when the invoice came from a shared
    # queue and so has none.
    def reassign_to!(new_assignee_id:, reassigned_by_id:, reason: nil)
      refuse_if_finished!
      raise ArgumentError, 'Task is already assigned to this employee' if new_assignee_id.to_s == assigned_employee_id.to_s
      raise ActiveRecord::RecordInvalid.new(self), "#{new_assignee_id} does not work AIM" unless Aim::Users.member?(new_assignee_id)

      target_id, target_name = resolve_owner(new_assignee_id)
      move_owner!(target_id, target_name, actor: Current.user&.dig('email').presence || Aim::Audited::SYSTEM_ACTOR,
                                          by: reassigned_by_id, reason: reason)
      @handover
    end

    # Work that reaches someone who is away goes to whoever covers for them
    # (AwayPeriod.assignee_for), as Paperboy's routing does: an upload into an
    # away person's queue, an invoice restored to one. Handed over by
    # #reassign_to!, so it is recorded as the away sweep's handovers are, and
    # it stays in its budget unit. Nothing happens when the owner is here, or
    # when their cover does not work AIM (the invoice then waits for them).
    # Returns the TaskReassignment, or nil.
    def hand_to_cover!(by: nil)
      return if assigned_employee_id.nil? || terminal?

      cover = AwayPeriod.assignee_for(assigned_employee_id.to_s).to_s
      return if cover == assigned_employee_id.to_s || !Aim::Users.member?(cover)

      reassign_to!(new_assignee_id: cover, reassigned_by_id: by.presence || assigned_employee_id,
                   reason: "#{assigned_to.presence || 'the owner'} is away")
    end

    # Move the invoice to another budget unit's shared queue. That changes its
    # budget unit, which is what billing charges, so the event says so; the
    # billing row takes the new BU when the worker next writes it (decided
    # 2026-09-25). Returns the invoice, or nil when it was already there.
    def move_to_unit!(unit, actor:)
      refuse_if_finished!

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

    def refuse_if_finished!
      raise Aim::Invoice::IllegalTransition, "#{batch_id} is finished and cannot be moved to another queue." if terminal?
    end

    def move_owner!(target_id, target_name, actor:, by: nil, unit: nil, exception: false, reason: nil)
      was = queue_owner
      was_unit = budget_unit
      note = "moved from #{was} to #{target_name || "the #{budget_unit} shared queue"}"
      note += ", and its budget unit from #{was_unit} to #{unit}" if unit
      note += ", kept in #{was_unit} by exception" if exception
      note += "; #{reason}" if reason.present?
      @handover = nil
      transaction do
        hand_over!(target_id, by: by, reason: reason.presence || note) if target_id && assigned_employee_id && target_id != assigned_employee_id
        changes = { assigned_employee_id: target_id, assigned_to: target_name, assignment_source: target_id ? 'reassigned' : nil }
        changes.merge!(budget_unit: unit, agency: nil) if unit
        update!(changes)
        events.create!(action: 'assignment', from_state: state, to_state: state, actor: actor, note: note)
      end
      forget_rule_coding! if unit
      self
    end

    # Reassignable's own handover: the TaskReassignment row, the assignee
    # written, and that write put in the edit trail. Called by name because
    # this model's #reassign_to! is the AIM move that wraps it.
    def hand_over!(target_id, by:, reason:)
      by = by.presence || Current.user&.dig('employee_id').presence || assigned_employee_id
      @handover = Reassignable.instance_method(:reassign_to!).bind_call(self, new_assignee_id: target_id,
                                                                              reassigned_by_id: by, reason: reason)
    end

    def resolve_owner(owner)
      value = owner.to_s.strip
      return [nil, nil] if value.blank? || value.casecmp?(SHARED_QUEUE)

      name = self.class.employee_name(value)
      raise ActiveRecord::RecordInvalid.new(self), "#{value} is not a known person" if name.nil?

      [value.to_i, name]
    end
  end
end
