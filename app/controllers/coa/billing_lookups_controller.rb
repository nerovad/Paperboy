# frozen_string_literal: true

module Coa
  class BillingLookupsController < BaseController
    def show
      @agency_options = options(Coa::Agency.all, :agency_id)
    end

    def divisions
      render_options(Coa::Division.where(agency_id: params[:agency_id]), :division_id)
    end

    def departments
      scope = Coa::Department.where(
        agency_id: params[:agency_id],
        division_id: params[:division_id]
      )
      render_options(scope, :department_id)
    end

    def units
      scope = Coa::Unit.where(
        agency_id: params[:agency_id],
        division_id: params[:division_id],
        department_id: params[:department_id]
      )
      render_options(scope, :unit_id)
    end

    private

    def render_options(scope, key)
      render json: options(scope, key)
    end

    def options(scope, key)
      scope.order(:long_name).pluck(:long_name, key).map do |long_name, value|
        { label: long_name, value: value }
      end
    end
  end
end
