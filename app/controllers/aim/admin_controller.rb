# frozen_string_literal: true

module Aim
  # AIM administration: who works AIM (item a.1). Budget unit coverage and
  # each BU's shared queue follow in a.2 and a.3. AIM admins see everyone; a
  # Group Admin (#131) the people of their groups' units. Managing narrows
  # either to the groups picked.
  #
  # Two views of the same people: a list, sortable and filterable, and one
  # collapsible group per budget unit. The choice is kept in the session.
  class AdminController < BaseController
    include Filterable

    before_action :require_people_manager

    VIEWS = %w[list bu].freeze
    ROLES = ['AIM Admin', 'BU Admin', 'User'].freeze

    # Each column the list sorts by, then by name (Filterable#sort_collection).
    SORTS = {
      'name' => ->(p) { [p.name.downcase] },
      'unit' => ->(p) { [p.unit.to_s, p.name.downcase] },
      'role' => ->(p) { [ROLES.index(p.roles.first).to_i, p.name.downcase] },
      'open' => ->(p) { [-p.open, p.name.downcase] }
    }.freeze

    # Each filter on the page (Filterable#apply_filters): the value a person
    # must have. The checkboxes send '1'.
    FILTERS = [
      { param: :agency, extractor: :agency.to_proc },
      { param: :unit, extractor: :unit.to_proc },
      { param: :agency_group, extractor: :group_ids.to_proc },
      { param: :role, extractor: :roles.to_proc },
      { param: :has_open, extractor: ->(p) { '1' if p.open.positive? } },
      { param: :via_group, extractor: ->(p) { '1' if p.via_group } },
      { param: :missing, extractor: ->(p) { '1' if p.missing } }
    ].freeze

    # unit_label and agency come from the Chart of Accounts (Aim::Units).
    # group_ids: the agency groups of the units they work (#131).
    Person = Struct.new(:employee_id, :first_name, :last_name, :unit, :unit_label, :agency, :member, :via_group,
                        :open, :missing, :roles, :inactive, :group_ids, keyword_init: true) do
      def name = missing ? "Employee #{employee_id}" : Employee.format_sort_name(first_name, last_name)
      def search_text = [name, first_name, employee_id, unit_label, agency, *roles].compact.join(' ')
    end

    def index
      @view = choose_view
      @sort = SORTS.key?(params[:sort]) ? params[:sort] : 'name'
      @filters = params.permit(:agency, :unit, :agency_group, :role, :has_open, :via_group, :missing, :inactive).to_h.compact_blank
      reading_database('list its users', alert: 'The AIM users could not be read.',
                                         empty: { people: [], units: [], agencies: [], groups: [], agency_groups: [] }) do
        @people = filtered(sort_collection(all_people, @sort, 'asc', SORTS, default_sort: 'name'))
        filter_options
        @groups = @people.group_by(&:unit_label).sort_by { |label, _| label } if @view == 'bu'
      end
    end

    private

    # What each filter offers: only values someone on the list has.
    def filter_options
      @agencies = all_people.filter_map(&:agency).uniq.sort.map { |agency| [coa.agency_label(agency), agency] }
      in_agency = all_people.select { |person| person.unit && (@filters['agency'].nil? || person.agency == @filters['agency']) }
      @units = in_agency.map { |person| [person.unit_label, person.unit] }.uniq.sort_by(&:last)
      held = all_people.flat_map(&:group_ids).uniq
      @agency_groups = helpers.aim_agency_groups.all.select { |group| held.include?(group.id.to_s) }.map { |g| [g.name, g.id.to_s] }
    end

    def choose_view
      session[:aim_admin_view] = params[:view] if VIEWS.include?(params[:view])
      VIEWS.include?(session[:aim_admin_view]) ? session[:aim_admin_view] : 'list'
    end

    # Everyone on the Admin list or in an AIM group, including list entries
    # GSABSS no longer knows -- a leaver shows up flagged instead of vanishing.
    def all_people
      @all_people ||= begin
        members = Aim::Member.all.index_by(&:employee_id)
        via_groups = Aim::Users.group_employee_ids.to_set
        ids = in_people_units((members.keys + via_groups.to_a).uniq)
        employees = Employee.where(id: ids).index_by(&:id)
        open = open_counts(ids)
        roles = Aim::Users.roles_by_person(ids)
        groups = group_ids_by_person(employees.values)
        ids.map do |id|
          person(id, employees[id], members[id], via_groups.include?(id), open, roles[id]).tap { |p| p.group_ids = groups.fetch(id, []) }
        end
      end
    end

    def coa = (@coa ||= Aim::Units.new)

    # { employee_id => [agency group id, ...] }: the groups of the units each
    # person works, home unit and granted ones, as the BU page counts them.
    def group_ids_by_person(employees)
      grants = Aim::UserBudgetUnit.where(employee_id: employees.map(&:id)).pluck(:employee_id, :budget_unit, :hidden)
      resolver = helpers.aim_agency_groups
      by_unit = helpers.aim_people_by_unit(employees.map { |e| [e.id, e.agency, e.unit] }, grants)
      by_unit.each_with_object(Hash.new { |h, k| h[k] = [] }) do |(unit, ids), out|
        group = resolver.for(nil, unit)
        ids.each { |id| out[id] |= [group.id.to_s] } if group
      end
    end

    # The people working in the units this page shows (aim_people_units): all
    # of them when that is every unit.
    def in_people_units(ids)
      units = helpers.aim_people_units
      return ids if units.nil?

      people = Employee.where(id: ids).pluck(:id, :agency, :unit)
      grants = Aim::UserBudgetUnit.where(employee_id: ids).pluck(:employee_id, :budget_unit, :hidden)
      helpers.aim_people_by_unit(people, grants).slice(*units).values.flatten.uniq
    end

    def person(id, employee, member, via_group, open, roles)
      unit = employee&.unit.presence
      Person.new(employee_id: id, first_name: employee&.first_name, last_name: employee&.last_name,
                 unit: unit, unit_label: unit ? coa.label(unit) : 'No unit',
                 agency: Coa::Agency.normalize_id(employee&.agency), member: member,
                 via_group: via_group, open: open.fetch(id, 0), missing: employee.nil?, roles: roles,
                 inactive: member.present? && !member.active? && !via_group)
    end

    def open_counts(ids)
      Aim::Invoice.where(assigned_employee_id: ids)
                  .where.not(state: Aim::Invoice::TERMINAL_STATES + Aim::Member::HANDS_OFF_STATES)
                  .group(:assigned_employee_id).count
    end

    # Inactive people are left out unless asked for.
    def filtered(list)
      list = apply_filters(list, filter_configs: FILTERS)
      @filters['inactive'] == '1' ? list : list.reject(&:inactive)
    end
  end
end
