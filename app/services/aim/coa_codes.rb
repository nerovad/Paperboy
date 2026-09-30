# frozen_string_literal: true

module Aim
  # Whether a code is in Paperboy's chart of accounts for an agency. The COA
  # (GSABSS, Coa::*) is the one source AIM validates coding against; Fusion's
  # value lists are not copied (decided 2026-09-23). Each list is read once
  # per instance.
  class CoaCodes
    # field on a rule => its list in Coa::FieldCatalog
    CATALOG_KEYS = {
      'budget_unit' => :unit, 'fund' => :fund, 'object_code' => :object, 'activity' => :activity,
      'function_code' => :function, 'program' => :program, 'major_program' => :major_program,
      'phase' => :phase, 'task' => :task, 'department' => :department
    }.freeze
    # field on a line => its list: the lists people choose from, as Fusion
    # offered them.
    OPTION_KEYS = CATALOG_KEYS.merge('dept_object' => :dept_object).freeze

    # field on a rule => [model, id column, scoped by agency?]
    LISTS = CATALOG_KEYS.transform_values do |key|
      Coa::FieldCatalog.fetch(key).then { |entry| [entry.model, entry.column, entry.agency_scoped] }
    end.freeze

    def initialize(agency)
      @agency = agency.to_s.upcase
      @lists = {}
    end

    # field on a line => [model, id column, scoped by agency?]
    OPTION_LISTS = OPTION_KEYS.transform_values do |key|
      Coa::FieldCatalog.fetch(key).then { |entry| [entry.model, entry.column, entry.agency_scoped] }
    end.freeze
    # The lists labelled by something other than short_name.
    NAMES = OPTION_KEYS.values.map { |key| Coa::FieldCatalog.fetch(key) }.reject { |entry| entry.name_column == :short_name }
                       .to_h { |entry| [entry.model, entry.name_column] }.freeze

    def agency? = Coa::Agency.exists?(agency_id: @agency)

    # What the COA links: a program belongs to a major program, a dept object
    # to an object. Blanks are filled from the chosen code; a code that
    # contradicts the link is an objection. Returns [fills, objections].
    def linkage(values)
      fills = {}
      objections = []
      if (program = values['program'].presence)
        major = Coa::Program.where(agency_id: @agency, program_id: program).pick(:major_program_id).to_s.strip
        if major.present?
          given = values['major_program'].to_s.strip
          fills['major_program'] = major if given.blank?
          objections << "program #{program} belongs to major program #{major}, not #{given}" if given.present? && !given.casecmp?(major)
        end
      end
      if (dept_object = values['dept_object'].presence)
        object = Coa::ObjectInference.where(agency_id: @agency, agency_object_code: dept_object).pick(:object_id).to_s.strip
        if object.present?
          fills['object_code'] = object if values['object_code'].blank?
          objections << "dept object #{dept_object} is object #{object}, not #{values['object_code']}" if values['object_code'].present? && values['object_code'].strip != object
        end
      end
      [fills, objections]
    end

    # [["2162 · OFFICE SUPPLIES", "2162"], ...] for a select, active codes
    # only, in code order.
    def options(field)
      @options ||= {}
      @options[field] ||= Coa::FieldCatalog.pairs(OPTION_KEYS.fetch(field), agency: @agency, active_only: true)
                                           .map { |code, label| ["#{code} · #{label.to_s.strip}".strip, code.to_s] }
    end

    def valid?(field, value)
      return true if value.blank?

      list(field).include?(value.to_s.strip.upcase)
    end

    # The fields whose values are not in the COA.
    def invalid_fields(values)
      values.reject { |field, value| !LISTS.key?(field) || valid?(field, value) }.keys
    end

    private

    def list(field)
      @lists[field] ||= begin
        entry = Coa::FieldCatalog.fetch(CATALOG_KEYS.fetch(field))
        entry.scope(@agency).pluck(entry.column).to_set { |id| id.to_s.strip.upcase }
      end
    end
  end
end
