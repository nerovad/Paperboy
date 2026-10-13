# frozen_string_literal: true

module Aim
  # A custom agency group's budget units (#131), ticked on its page. A unit
  # ticked here leaves its agency's group; one unticked goes back to it. A
  # unit already in another custom group is left there. AIM Admins only.
  class AgencyGroupUnitsController < BaseController
    before_action :require_aim_user_admin

    def update
      group = Aim::AgencyGroup.find(params[:id])
      return redirect_to(aim_agency_group_path(group), alert: "An agency's group has every unit no custom group has.") unless group.custom

      offered = Coa::Unit.where(agency_id: group.agency_id, active: true).distinct.pluck(:unit_id)
      picked = Array(params[:units]).map(&:to_s) & offered
      taken = Aim::AgencyGroupUnit.where(agency_id: group.agency_id).where.not(agency_group_id: group.id).pluck(:budget_unit)
      Aim::AgencyGroupUnit.transaction do
        group.units.where.not(budget_unit: picked).delete_all
        (picked - taken - group.units.pluck(:budget_unit)).each do |unit|
          group.units.create!(agency_id: group.agency_id, budget_unit: unit, added_by: current_user_email)
        end
      end
      redirect_to aim_agency_group_path(group, anchor: 'units'),
                  notice: "#{helpers.pluralize(group.units.count, 'budget unit')} in #{group.name}."
    end
  end
end
