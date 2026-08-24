# frozen_string_literal: true

module Coa
  class BillingLookupsController < BaseController
    before_action -> { require_app_feature('coa', 'billing_lookup', fallback: coa_root_path) }

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

    def objects
      render json: billing_options.options_for(:object)
    end

    def activities
      render_agency_options(:activity)
    end

    def cfunctions
      render_agency_options(:function)
    end

    def programs
      render_agency_options(:program)
    end

    def phases
      render_agency_options(:phase)
    end

    def tasks
      render_agency_options(:task)
    end

    private

    def render_options(scope, key)
      render json: options(scope, key)
    end

    def render_agency_options(field)
      render json: billing_options.options_for(field)
    end

    def options(scope, key)
      scope.order(:long_name).pluck(:long_name, key).map do |long_name, value|
        label = "#{value} - #{long_name}"
        { label: label, value: value }
      end
    end

    def billing_options
      @billing_options ||= BillingOptions.new(agency_id: params[:agency_id])
    end
  end
end
