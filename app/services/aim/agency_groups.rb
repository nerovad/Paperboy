# frozen_string_literal: true

module Aim
  # Which agency group serves what (#131), read once per request. A BU ticked
  # into a custom group is that group's; every other BU is its agency's own
  # group's, made from the COA the first time it is needed. An invoice goes by
  # its stored agency, or its unit's when it has none yet.
  #
  #   groups = Aim::AgencyGroups.new
  #   groups.for_invoice(invoice)     # => Aim::AgencyGroup
  #   groups.invoices([group])        # => the invoices that group serves
  class AgencyGroups
    def initialize(units: Aim::Units.new)
      @units = units
      @groups = Aim::AgencyGroup.by_name.to_a
      @custom = Aim::AgencyGroupUnit.pluck(:agency_id, :budget_unit, :agency_group_id)
                                    .to_h { |agency, unit, group| [[agency, unit], group] }
      @covers = Aim::AgencyGroupCoverage.pluck(:agency_group_id, :covered_group_id)
                                        .group_by(&:first).transform_values { |pairs| pairs.map(&:last) }
    end

    def all = @groups

    def find(id) = @groups.find { |group| group.id == id.to_i }

    # The group serving a BU of an agency; nil without either.
    def for(agency, unit)
      agency = agency.presence || @units.agency_of(unit)
      return if agency.blank?

      custom = @custom[[agency, unit.to_s]]
      return find(custom) if custom

      @groups.find { |group| !group.custom && group.agency_id == agency } || remember(Aim::AgencyGroup.for_agency!(agency))
    end

    def for_invoice(invoice) = self.for(invoice.agency, invoice.budget_unit)

    # What +groups+ work (nil: every group): themselves and the groups their
    # Fiscal also processes. One step only: covering a group does not bring
    # the groups it covers.
    def reach(groups)
      return nil if groups.nil?

      ids = groups.flat_map { |group| [group.id, *@covers.fetch(group.id, [])] }.uniq
      @groups.select { |group| ids.include?(group.id) }
    end

    # The groups whose Fiscal also processes +group+.
    def covered_by(group) = @groups.select { |other| @covers.fetch(other.id, []).include?(group.id) }

    def covers(group) = @groups.select { |other| @covers.fetch(group.id, []).include?(other.id) }

    # Whether +groups+ (nil: every group) include the one serving the invoice.
    def serves?(groups, invoice)
      return true if groups.nil?

      group = for_invoice(invoice)
      group.present? && groups.map(&:id).include?(group.id)
    end

    # The budget units a group serves: a custom group's own; for an agency's
    # group, the agency's active COA units no custom group has.
    def units_of(group)
      return custom_units(group.agency_id, group.id) if group.custom

      coa_units(group.agency_id) - custom_units(group.agency_id)
    end

    # The invoices +groups+ serve (nil: every invoice), as one query.
    def invoices(groups)
      return Aim::Invoice.all if groups.nil?

      conditions = groups.map { |group| condition(group) }
      conditions.empty? ? Aim::Invoice.none : Aim::Invoice.where(conditions.join(' OR '))
    end

    private

    def remember(group)
      @groups << group
      group
    end

    # Units ticked into custom groups of an agency; only +group_id+'s if given.
    def custom_units(agency, group_id = nil)
      @custom.filter_map { |(a, unit), id| unit if a == agency && (group_id.nil? || id == group_id) }.sort
    end

    def coa_units(agency)
      @coa_units ||= {}
      @coa_units[agency] ||= Coa::Unit.where(agency_id: agency, active: true).distinct.order(:unit_id).pluck(:unit_id)
    rescue ActiveRecord::ActiveRecordError
      []
    end

    # An invoice with no stored agency is matched by its unit alone.
    def condition(group)
      agency = group.agency_id
      if group.custom
        units = custom_units(agency, group.id)
        return '1=0' if units.empty?

        return sql('(budget_unit IN (?) AND (agency = ? OR agency IS NULL))', units, agency)
      end

      coa = coa_units(agency)
      mine = coa.any? ? sql('(agency = ? OR (agency IS NULL AND budget_unit IN (?)))', agency, coa) : sql('agency = ?', agency)
      taken = custom_units(agency)
      taken.empty? ? mine : "(#{mine} AND (budget_unit IS NULL OR #{sql('budget_unit NOT IN (?)', taken)}))"
    end

    def sql(*args) = Aim::Invoice.sanitize_sql_array(args)
  end
end
