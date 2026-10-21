# frozen_string_literal: true

module Aim
  # One line of an invoice's history. Written once and never changed: a
  # persisted event is read-only, so it can be neither edited nor deleted.
  #
  # Each records who held the invoice after it (#190): the person whose queue
  # it is in (none for a BU's shared queue) and its budget unit, copied from
  # the invoice as the event is written. Every event goes through here, so a
  # move, a state change or anything else is covered without its caller
  # saying so. The worker's Db writes the same from its own INSERT.
  class InvoiceEvent < Record
    include Aim::AppendOnly

    HOLDER_SOURCES = %w[recorded inferred].freeze

    belongs_to :invoice, class_name: 'Aim::Invoice'

    validates :action, :actor, presence: true
    validates :holder_source, inclusion: { in: HOLDER_SOURCES }, allow_nil: true

    before_create :record_holder, unless: :holder_source

    private

    def record_holder
      return unless invoice

      self.holder_employee_id = invoice.assigned_employee_id
      self.holder_name = invoice.assigned_to.presence
      self.holder_budget_unit = invoice.budget_unit
      self.holder_source = 'recorded'
    end
  end
end
