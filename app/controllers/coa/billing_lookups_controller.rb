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
      render_options(Coa::Object.all, :object_id)
    end

    def activities
      render_agency_options(Coa::Activity, :activity_id)
    end

    def cfunctions
      render_agency_options(Coa::Function, :function_id)
    end

    def programs
      render_agency_options(Coa::Program, :program_id)
    end

    def phases
      render_agency_options(Coa::Phase, :phase_id)
    end

    def tasks
      render_agency_options(Coa::Task, :task_id)
    end

    private

    def render_options(scope, key)
      render json: options(scope, key)
    end

    def render_agency_options(model, key)
      render_options(agency_scope(model), key)
    end

    def agency_scope(model)
      model.where(agency_id: params[:agency_id])
    end

    def options(scope, key)
      scope.order(:long_name).pluck(:long_name, key).map do |long_name, value|
        label = "#{value} - #{long_name}"
        { label: label, value: value }
      end
    end
  end
end
