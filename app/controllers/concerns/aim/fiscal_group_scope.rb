# frozen_string_literal: true

module Aim
  # The Fiscal lists by agency group (#131): what the groups picked in
  # Managing serve, and the By BU sections. Needs @records.
  module FiscalGroupScope
    extend ActiveSupport::Concern

    private

    # By BU; with more than one agency group on the page, by group then BU,
    # each heading naming its group.
    def fiscal_groups
      coa = Aim::Units.new
      groups = helpers.aim_agency_groups
      by_unit = @records.group_by { |record| [groups.for_invoice(record.invoice), record.invoice.budget_unit] }
      several = by_unit.keys.map(&:first).uniq.size > 1
      by_unit.sort_by { |(group, unit), _| [group&.name.to_s, unit.to_s] }.map do |(group, unit), rows|
        [unit, [(group.name if several && group), coa.label(unit)].compact.join(' › '), rows]
      end
    end

    # The invoices of the groups picked in Managing.
    def served_invoices = helpers.aim_agency_groups.invoices(helpers.aim_managing_groups)
  end
end
