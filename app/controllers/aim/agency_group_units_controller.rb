# frozen_string_literal: true

module Aim
  # Which budget units an agency group has (#131), ticked on its page. AIM
  # Admins only.
  #
  # A custom group: ticked units are its own, unticked ones go back to their
  # agency's group; a unit already in another custom group is left there.
  # An agency's group: unticked units move to the custom group picked (or a
  # new one, named on the spot), and units ticked back leave their custom
  # group. Every unit is always in exactly one group.
  class AgencyGroupUnitsController < BaseController
    before_action :require_aim_user_admin
    before_action :set_group

    def update
      offered = Coa::Unit.where(agency_id: @group.agency_id, active: true).distinct.pluck(:unit_id)
      picked = Array(params[:units]).map(&:to_s) & offered
      Aim::AgencyGroupUnit.transaction { @group.custom ? update_custom(picked) : update_agency(offered, picked) }
      redirect_to aim_agency_group_path(@group, anchor: 'units'), notice: 'Budget units saved.'
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      redirect_to aim_agency_group_path(@group, anchor: 'units'), alert: e.message
    end

    private

    def set_group
      @group = Aim::AgencyGroup.find(params[:id])
    end

    def rows = Aim::AgencyGroupUnit.where(agency_id: @group.agency_id)

    def update_custom(picked)
      taken = rows.where.not(agency_group_id: @group.id).pluck(:budget_unit)
      @group.units.where.not(budget_unit: picked).delete_all
      add(@group, picked - taken - @group.units.pluck(:budget_unit))
    end

    def update_agency(offered, picked)
      custom = rows.pluck(:budget_unit)
      leaving = offered - picked - custom
      rows.where(budget_unit: picked).delete_all
      return if leaving.empty?

      add(destination, leaving)
    end

    # The custom group unticked units move to: one of this agency's, or a new
    # one named in the form.
    def destination
      if params[:move_to] == 'new'
        return Aim::AgencyGroup.create!(name: params[:new_group_name], agency_id: @group.agency_id, custom: true,
                                        updated_by: current_user_email)
      end

      group = Aim::AgencyGroup.find_by(id: params[:move_to], agency_id: @group.agency_id, custom: true)
      group || raise(ArgumentError, 'Pick the custom group the unticked units go to, or name a new one.')
    end

    def add(group, units)
      units.each { |unit| group.units.create!(agency_id: group.agency_id, budget_unit: unit, added_by: current_user_email) }
    end
  end
end
