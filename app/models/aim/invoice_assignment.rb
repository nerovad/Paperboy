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
    def reassign!(owner, actor:)
      raise Aim::Invoice::IllegalTransition, "#{batch_id} is finished and cannot be moved to another queue." if terminal?

      was = queue_owner
      target_id, target_name = resolve_owner(owner)
      return if target_id == assigned_employee_id && (target_id || shared_queue?)

      transaction do
        update!(assigned_employee_id: target_id, assigned_to: target_name,
                assignment_source: target_id ? 'reassigned' : nil)
        events.create!(action: 'assignment', from_state: state, to_state: state, actor: actor,
                       note: "moved from #{was} to #{target_name || "the #{budget_unit} shared queue"}")
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
