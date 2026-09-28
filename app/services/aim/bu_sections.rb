# frozen_string_literal: true

module Aim
  # Invoices grouped budget unit -> its shared queue and each person -> their
  # invoices, for the BU page and the Pipeline's Ready for Approval
  # (app/views/aim/shared/_bu_sections.html.erb).
  module BuSections
    # row: their Aim::UserBudgetUnit for this BU, if any -- it carries the
    # shared queue switch and BU Admin.
    Person = Struct.new(:employee_id, :name, :invoices, :row, keyword_init: true) do
      def shared_queue? = row.present? && (row.shared_queue || row.bu_admin)
    end

    Section = Struct.new(:unit, :label, :shared, :people, keyword_init: true) do
      def invoice_count = shared.size + people.sum { |person| person.invoices.size }
      def covered? = people.any?(&:shared_queue?)
      def administered? = people.any? { |person| person.row&.bu_admin && !person.row.hidden }
    end

    module_function

    # units: the BUs to show, in order (default: those the invoices are in).
    # people: { unit => { employee_id => "Last, First" } } to list even with no
    # invoices; rows: { [employee_id, unit] => Aim::UserBudgetUnit }.
    def build(invoices, coa:, units: nil, people: {}, rows: {})
      by_unit = invoices.group_by(&:budget_unit)
      (units || by_unit.keys.sort_by(&:to_s)).map do |unit|
        section(unit, coa, by_unit.fetch(unit, []), people.fetch(unit, {}).dup, rows)
      end
    end

    def section(unit, coa, invoices, people, rows)
      owned = invoices.group_by(&:assigned_employee_id)
      # Anyone who owns an invoice here is listed, even without the BU.
      (owned.keys.compact - people.keys).each { |id| people[id] = owned[id].first.assigned_to.presence || "Employee #{id}" }
      Section.new(unit: unit, label: coa.label(unit), shared: owned.fetch(nil, []),
                  people: people.sort_by { |_, name| name.downcase }.map do |id, name|
                    Person.new(employee_id: id, name: name, invoices: owned.fetch(id, []), row: rows[[id, unit]])
                  end)
    end
  end
end
