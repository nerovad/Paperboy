# frozen_string_literal: true

module Coa
  class BillingOptions
    FIELD_CONFIG = {
      object: [Coa::Object, :object_id, false],
      activity: [Coa::Activity, :activity_id, true],
      function: [Coa::Function, :function_id, true],
      program: [Coa::Program, :program_id, true],
      phase: [Coa::Phase, :phase_id, true],
      task: [Coa::Task, :task_id, true]
    }.freeze

    def initialize(agency_id: nil, restrict_to_agency: false)
      @agency_id = agency_id
      @restrict_to_agency = restrict_to_agency
    end

    def all
      FIELD_CONFIG.to_h { |field, _configuration| [field, options_for(field)] }
    end

    def options_for(field)
      model, key, agency_specific = FIELD_CONFIG.fetch(field.to_sym)
      return [] if (agency_specific || restrict_to_agency) && agency_id.blank?

      scope = option_scope(model, agency_specific)
      scope.order(:long_name).pluck(:long_name, key).map do |long_name, value|
        { label: "#{value} - #{long_name}", value: value }
      end
    end

    private

    attr_reader :agency_id, :restrict_to_agency

    def option_scope(model, agency_specific)
      return model.where(agency_id: agency_id) if agency_specific
      return model.all unless restrict_to_agency

      model.joins(:object_inferences)
           .where(agency_objects: { agency_id: agency_id })
           .distinct
    end
  end
end
