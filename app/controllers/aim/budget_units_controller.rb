# frozen_string_literal: true

module Aim
  # The BU page (item a.2): budget unit -> its shared queue and each person ->
  # their invoices, collapsible, in the Ready for Approval style. "My BUs" for a
  # BU Admin, their BUs only; "By BU" for AIM Admins and Staff, every GSA BU.
  # In queue by default, with the pipeline a tab away.
  class BudgetUnitsController < BaseController
    include Aim::StageTabs

    before_action :remember_queue_page, only: :index

    Person = Struct.new(:employee_id, :name, :invoices, keyword_init: true)
    Section = Struct.new(:unit, :label, :shared, :people, keyword_init: true) do
      def invoice_count = shared.size + people.sum { |person| person.invoices.size }
    end

    def index
      units = helpers.aim_bu_admin_units
      return redirect_to(aim_root_path, alert: 'You are not a BU Admin.') if units == []

      labels = Aim::UserBudgetUnit.unit_options.to_h(&:reverse)
      @units = (units || labels.keys).sort
      invoices = invoices_for_tab(Aim::Invoice.where(budget_unit: @units)).group_by(&:budget_unit)
      people = people_by_unit
      @sections = @units.map { |unit| section(unit, labels, people.fetch(unit, {}), invoices.fetch(unit, [])) }
    end

    private

    def section(unit, labels, people, invoices)
      owned = invoices.group_by(&:assigned_employee_id)
      # Anyone who owns an invoice here is listed, even without the BU.
      (owned.keys.compact - people.keys).each { |id| people[id] = owned[id].first.assigned_to.presence || "Employee #{id}" }
      Section.new(unit: unit, label: labels.fetch(unit, unit), shared: owned.fetch(nil, []),
                  people: people.sort_by { |_, name| name.downcase }.map do |id, name|
                    Person.new(employee_id: id, name: name, invoices: owned.fetch(id, []))
                  end)
    end

    # { unit => { employee_id => "Last, First" } } for the people who work AIM:
    # their home unit unless hidden, and every BU granted on their profile.
    def people_by_unit
      employees = Aim::Users.all.to_a
      names = employees.to_h { |e| [e.id, "#{e.last_name}, #{e.first_name}"] }
      rows = Aim::UserBudgetUnit.where(employee_id: names.keys, budget_unit: @units).to_a
      hidden = rows.select(&:hidden).to_set { |row| [row.employee_id, row.budget_unit] }
      result = Hash.new { |hash, unit| hash[unit] = {} }
      employees.each do |e|
        result[e.unit][e.id] = names[e.id] if e.unit.present? && !hidden.include?([e.id, e.unit])
      end
      rows.reject(&:hidden).each { |row| result[row.budget_unit][row.employee_id] = names[row.employee_id] }
      result
    end
  end
end
