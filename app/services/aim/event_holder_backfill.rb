# frozen_string_literal: true

module Aim
  # Fills in who held each invoice after its older events (#190), for the
  # events written before Aim::InvoiceEvent recorded it. Marked 'inferred'.
  #
  # Each invoice's history is walked backwards from who holds it now. An
  # event takes the holder of the moment; crossing an assignment event
  # ("moved from X to Y", with any budget unit change in the same note) steps
  # the holder back to X. A recorded event is taken as fact. When a note
  # cannot be read, or its "to" is not who held the invoice at that point
  # (a move that left no event), the walk stops: that event and everything
  # older stay unknown (NULL) rather than guessed.
  #
  # A name is matched to an employee id from the pairs on aim.invoices and the
  # recorded events -- also for an invoice owned by name alone, from before
  # owners were employees; a name with no single id keeps its name and no id.
  #
  # Events are read-only (Aim::AppendOnly). The backfill writes the holder
  # columns alone, with update_all, and only where holder_source is NULL:
  # the event itself is not changed. A second run, or a run after a crash,
  # fills only what is still NULL, and leaves the same unknowns unknown.
  class EventHolderBackfill
    NOTE = /\Amoved from (?<from>.+?) to (?<to>.+?)(?=, and its budget unit |, kept in |; |\z)/m
    UNIT_MOVE = /(?:its budget unit from|budget unit changed from) (?<from>\S+) to (?<to>[^,;\s]+)/
    SHARED = /\A(?:SHARED|the (?<unit>\S+) shared queue)\z/

    Holder = Data.define(:employee_id, :name, :budget_unit) do
      def shared? = name.nil?
    end

    Result = Data.define(:invoices, :inferred, :unknown)

    def call
      invoices = inferred = unknown = 0
      pending_invoice_ids.each_slice(200) do |ids|
        Aim::Invoice.where(id: ids).includes(:events).find_each do |invoice|
          filled, left = backfill(invoice)
          invoices += 1
          inferred += filled
          unknown += left
        end
      end
      Result.new(invoices: invoices, inferred: inferred, unknown: unknown)
    end

    private

    def pending_invoice_ids = Aim::InvoiceEvent.where(holder_source: nil).distinct.pluck(:invoice_id)

    # [events filled, events left unknown] for one invoice.
    def backfill(invoice)
      name = invoice.assigned_to.presence
      holder = Holder.new(invoice.assigned_employee_id || (name && employee_ids[name.downcase]), name, invoice.budget_unit)
      filled = left = 0
      invoice.events.sort_by { |event| [event.created_at, event.id] }.reverse_each do |event|
        if event.holder_source
          holder = Holder.new(event.holder_employee_id, event.holder_name, event.holder_budget_unit)
        elsif holder.nil? || !consistent?(event, holder)
          holder = nil
          left += 1
          next
        else
          write(event, holder)
          filled += 1
        end
        holder = before(event, holder) if holder && event.action == 'assignment'
      end
      [filled, left]
    end

    # Does an assignment's "to" match who held the invoice just after it?
    def consistent?(event, holder)
      return true unless event.action == 'assignment'

      to = NOTE.match(event.note.to_s)&.[](:to)
      return false if to.nil?

      to_shared = SHARED.match?(to)
      to_shared ? holder.shared? : to.casecmp?(holder.name.to_s)
    end

    # Who held the invoice just before an assignment, or nil when the note
    # cannot say.
    def before(event, holder)
      note = event.note.to_s
      from = NOTE.match(note)&.[](:from)
      return if from.nil?

      unit = UNIT_MOVE.match(note)&.[](:from)
      unit = nil if unit == 'none'
      if (shared = SHARED.match(from))
        Holder.new(nil, nil, shared[:unit] || unit || holder.budget_unit)
      else
        Holder.new(employee_ids[from.downcase], from, unit || holder.budget_unit)
      end
    end

    def write(event, holder)
      Aim::InvoiceEvent.where(id: event.id, holder_source: nil)
                       .update_all(holder_employee_id: holder.employee_id, holder_name: holder.name,
                                   holder_budget_unit: holder.budget_unit, holder_source: 'inferred')
    end

    # { lowercased name => employee id } for names with exactly one id.
    def employee_ids
      @employee_ids ||= begin
        pairs = Aim::Invoice.where.not(assigned_employee_id: nil).where.not(assigned_to: [nil, ''])
                            .distinct.pluck(:assigned_to, :assigned_employee_id) +
                Aim::InvoiceEvent.where(holder_source: 'recorded').where.not(holder_employee_id: nil)
                                 .distinct.pluck(:holder_name, :holder_employee_id)
        pairs.group_by { |name, _| name.downcase }
             .filter_map { |name, rows| [name, rows.first.last] if rows.map(&:last).uniq.one? }.to_h
      end
    end
  end
end
