# frozen_string_literal: true

module Aim
  # Which budget units an agency group has (#131), ticked on its page. The
  # same setting as AIM's Budget Units, seen one agency at a time. AIM Admins
  # only.
  #
  # An agency's own group: ticked units are the ones AIM uses, other than
  # those in custom groups; unticking one stops AIM using it.
  # A custom group: ticked units are its own, and AIM uses them; unticking one
  # sends it back to the agency's group. A unit already in another custom
  # group is left there.
  class AgencyGroupUnitsController < BaseController
    before_action :require_aim_user_admin
    before_action :set_group

    def update
      offered = Coa::Unit.where(agency_id: @group.agency_id, active: true).distinct.pluck(:unit_id)
      picked = Array(params[:units]).map(&:to_s) & offered
      Aim::AgencyGroupUnit.transaction { @group.custom ? update_custom(picked) : update_agency(picked) }
      redirect_to aim_agency_group_path(@group, tab: 'units'), notice: 'Budget units saved.'
    rescue ActiveRecord::RecordInvalid => e
      redirect_to aim_agency_group_path(@group, tab: 'units'), alert: e.message
    end

    private

    def set_group
      @group = Aim::AgencyGroup.find(params[:id])
    end

    def rows = Aim::AgencyGroupUnit.where(agency_id: @group.agency_id)

    def used = Aim::Units.new.units_of(@group.agency_id)

    # Units in custom groups stay in use; the rest are what was ticked.
    def update_agency(picked)
      Aim::EnabledUnit.set_agency_units!(@group.agency_id, picked + rows.pluck(:budget_unit), by: current_user_email)
    end

    def update_custom(picked)
      taken = rows.where.not(agency_group_id: @group.id).pluck(:budget_unit)
      @group.units.where.not(budget_unit: picked).delete_all
      (picked - taken - @group.units.pluck(:budget_unit)).each do |unit|
        @group.units.create!(agency_id: @group.agency_id, budget_unit: unit, added_by: current_user_email)
      end
      missing = picked - taken - used
      Aim::EnabledUnit.set_agency_units!(@group.agency_id, used + missing, by: current_user_email) if missing.any?
    end
  end
end
