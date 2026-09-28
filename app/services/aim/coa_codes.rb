# frozen_string_literal: true

module Aim
  # Whether a code is in Paperboy's chart of accounts for an agency. The COA
  # (GSABSS, Coa::*) is the one source AIM validates coding against; Fusion's
  # value lists are not copied (decided 2026-09-23). Each list is read once
  # per instance.
  class CoaCodes
    # field on a rule => [model, id column, scoped by agency?]
    LISTS = {
      'budget_unit' => [Coa::Unit, :unit_id, true],
      'fund' => [Coa::Fund, :fund_id, false],
      'object_code' => [Coa::Object, :object_id, false],
      'activity' => [Coa::Activity, :activity_id, true],
      'function_code' => [Coa::Function, :function_id, true],
      'program' => [Coa::Program, :program_id, true],
      'major_program' => [Coa::MajorProgram, :major_program_id, true],
      'phase' => [Coa::Phase, :phase_id, true],
      'task' => [Coa::Task, :task_id, true],
      'department' => [Coa::Department, :department_id, true]
    }.freeze

    def initialize(agency)
      @agency = agency.to_s.upcase
      @lists = {}
    end

    # field on a line => [model, id column, name column, scoped by agency?]:
    # the lists people choose from, as Fusion offered them.
    OPTION_LISTS = LISTS.merge('dept_object' => [Coa::ObjectInference, :agency_object_code, true]).freeze
    NAMES = { Coa::ObjectInference => :agency_object_name }.freeze

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
      @options[field] ||= begin
        model, column, scoped = OPTION_LISTS.fetch(field)
        scope = scoped ? model.where(agency_id: @agency) : model.all
        scope = scope.where(active: true) if model.column_names.include?('active')
        name = NAMES.fetch(model, :short_name)
        scope.order(column).pluck(column, name).map { |code, label| ["#{code} · #{label.to_s.strip}".strip, code.to_s] }
      end
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
        model, column, scoped = LISTS.fetch(field)
        scope = scoped ? model.where(agency_id: @agency) : model.all
        scope.pluck(column).to_set { |id| id.to_s.strip.upcase }
      end
    end
  end
end
