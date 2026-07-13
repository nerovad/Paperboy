# frozen_string_literal: true

module Coa
  class BaseController < ApplicationController
    before_action :require_system_admin

    helper_method :coa_sidebar_resources, :coa_sidebar_collection_path

    private

    def coa_sidebar_resources
      [
        Coa::Agency,
        Coa::Division,
        Coa::Department,
        Coa::Unit,
        Coa::Activity,
        Coa::Function,
        Coa::Fund,
        Coa::MajorProgram,
        Coa::Object,
        Coa::Phase,
        Coa::Program,
        Coa::RevenueSource,
        Coa::ObjectInference,
        Coa::SubUnit,
        Coa::Task
      ]
    end

    def coa_sidebar_collection_path(model_class)
      public_send("coa_#{coa_route_collection_name(model_class)}_path")
    end

    def coa_route_collection_name(model_class)
      {
        'Coa::Agency' => 'agencies',
        'Coa::Activity' => 'activities',
        'Coa::Department' => 'departments',
        'Coa::Division' => 'divisions',
        'Coa::Function' => 'functions',
        'Coa::Fund' => 'funds',
        'Coa::MajorProgram' => 'major_programs',
        'Coa::Object' => 'objects',
        'Coa::ObjectInference' => 'object_inferences',
        'Coa::Phase' => 'phases',
        'Coa::Program' => 'programs',
        'Coa::RevenueSource' => 'revenue_sources',
        'Coa::SubUnit' => 'sub_units',
        'Coa::Task' => 'tasks',
        'Coa::Unit' => 'units'
      }.fetch(model_class.name)
    end
  end
end
