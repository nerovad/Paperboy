# frozen_string_literal: true

module Coa
  # The Billing lookup's code lists: "value - long_name", in long_name order,
  # inactive codes included. The lists themselves are Coa::FieldCatalog's.
  class BillingOptions
    FIELDS = %i[object activity function program phase task].freeze

    # field => [model, id column, scoped by agency?], as the catalog has it.
    FIELD_CONFIG = FIELDS.to_h do |field|
      entry = Coa::FieldCatalog.fetch(field)
      [field, [entry.model, entry.column, entry.agency_scoped]]
    end.freeze

    def initialize(agency_id: nil, restrict_to_agency: false)
      @agency_id = agency_id
      @restrict_to_agency = restrict_to_agency
    end

    def all
      FIELD_CONFIG.to_h { |field, _configuration| [field, options_for(field)] }
    end

    def options_for(field)
      field = field.to_sym
      raise KeyError, "key not found: #{field.inspect}" unless FIELDS.include?(field)

      entry = Coa::FieldCatalog.fetch(field)
      return [] if (entry.agency_scoped || restrict_to_agency) && agency_id.blank?

      Coa::FieldCatalog.pairs(field, scope: option_scope(entry), name: :long_name, order: :long_name)
                       .map { |value, long_name| { label: "#{value} - #{long_name}", value: value } }
    end

    private

    attr_reader :agency_id, :restrict_to_agency

    def option_scope(entry)
      return entry.scope(agency_id) if entry.agency_scoped
      return entry.model.all unless restrict_to_agency

      entry.model.joins(:object_inferences)
           .where(agency_objects: { agency_id: agency_id })
           .distinct
    end
  end
end
