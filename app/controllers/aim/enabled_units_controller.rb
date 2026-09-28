# frozen_string_literal: true

module Aim
  # Admin -> AIM's budget units (2026-09-28): which Chart of Accounts units AIM
  # works with. Every agency with active units is listed; ticking "Entire
  # agency" takes the agency itself, units the COA adds later included. One
  # setting for Upload, Move, profiles and By BU. AIM Admins only.
  class EnabledUnitsController < BaseController
    before_action :require_aim_user_admin

    def index
      @coa = Aim::Units.new(every_agency: true)
      @current = Aim::Units.new
      enabled = Aim::EnabledUnit.pluck(:agency_id, :unit_id)
      @whole = enabled.select { |_, unit| unit.nil? }.to_set(&:first)
      @single = enabled.select { |_, unit| unit.present? }.to_set
    end

    def update
      coa = Aim::Units.new(every_agency: true)
      agencies = Array(params[:agencies]).map(&:to_s) & coa.agencies
      units = Array(params[:units]).map(&:to_s).filter_map { |unit| [coa.agency_of(unit), unit] if coa.valid?(unit) }
      Aim::EnabledUnit.replace!(agencies: agencies, units: units, by: current_user_email)
      redirect_to aim_enabled_units_path,
                  notice: "Saved: #{helpers.pluralize(agencies.size, 'whole agency')} and " \
                          "#{helpers.pluralize(units.count { |agency, _| agencies.exclude?(agency) }, 'single unit')}."
    end
  end
end
