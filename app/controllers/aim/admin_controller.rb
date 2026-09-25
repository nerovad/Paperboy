# frozen_string_literal: true

module Aim
  # AIM administration: who works AIM (item a.1). Budget unit coverage and
  # each BU's shared queue follow in a.2 and a.3. Only AIM admins reach it.
  #
  # Two views of the same people: a list, sortable and filterable, and one
  # collapsible group per budget unit. The choice is kept in the session.
  class AdminController < BaseController
    before_action :require_aim_user_admin

    VIEWS = %w[list bu].freeze
    SORTS = %w[name unit open].freeze

    Person = Struct.new(:employee_id, :first_name, :last_name, :unit, :unit_name, :member, :via_group, :open,
                        :missing, keyword_init: true) do
      def name = missing ? "Employee #{employee_id}" : "#{last_name}, #{first_name}"
      def unit_label = [unit, unit_name&.titleize].compact_blank.join(' · ').presence || 'No unit'
      def search_text = [name, first_name, employee_id, unit, unit_name, ('group' if via_group)].compact.join(' ')
    end

    def index
      @view = choose_view
      @sort = SORTS.include?(params[:sort]) ? params[:sort] : 'name'
      @filters = params.permit(:unit, :has_open, :via_group, :missing).to_h.compact_blank
      @people = filtered(sorted(all_people))
      @units = all_people.select(&:unit).map { |person| [person.unit_label, person.unit] }.uniq.sort_by(&:last)
      @groups = @people.group_by(&:unit_label).sort_by { |label, _| label } if @view == 'bu'
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.error "AIM could not list its users: #{e.message}"
      @people = []
      @units = []
      @groups = []
      flash.now[:alert] = 'The AIM users could not be read.'
    end

    private

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
        ids = (members.keys + via_groups.to_a).uniq
        employees = Employee.where(id: ids).index_by(&:id)
        unit_names = Coa::Unit.where(unit_id: employees.values.map(&:unit).compact.uniq).pluck(:unit_id, :long_name).to_h
        open = open_counts(ids)
        ids.map { |id| person(id, employees[id], members[id], via_groups.include?(id), open, unit_names) }
      end
    end

    def person(id, employee, member, via_group, open, unit_names)
      Person.new(employee_id: id, first_name: employee&.first_name, last_name: employee&.last_name,
                 unit: employee&.unit.presence, unit_name: unit_names[employee&.unit], member: member,
                 via_group: via_group, open: open.fetch(id, 0), missing: employee.nil?)
    end

    def open_counts(ids)
      Aim::Invoice.where(assigned_employee_id: ids)
                  .where.not(state: Aim::Invoice::TERMINAL_STATES + Aim::Member::HANDS_OFF_STATES)
                  .group(:assigned_employee_id).count
    end

    def sorted(list)
      case @sort
      when 'unit' then list.sort_by { |p| [p.unit.to_s, p.name.downcase] }
      when 'open' then list.sort_by { |p| [-p.open, p.name.downcase] }
      else list.sort_by { |p| p.name.downcase }
      end
    end

    def filtered(list)
      list = list.select { |p| p.unit == params[:unit] } if params[:unit].present?
      list = list.select { |p| p.open.positive? } if params[:has_open] == '1'
      list = list.select(&:via_group) if params[:via_group] == '1'
      list = list.select(&:missing) if params[:missing] == '1'
      list
    end
  end
end
