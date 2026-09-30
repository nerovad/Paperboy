# frozen_string_literal: true

module Coa
  # The Chart of Accounts lists a coding field is chosen from, in one table:
  # for each field, the Coa model, its code column, and whether the list is
  # per agency. Billing (Coa::BillingOptions) and AIM (Aim::CoaCodes) both
  # read it and differ only in how they label, order and filter, which the
  # callers pass to .pairs.
  #
  #   Coa::FieldCatalog.fetch(:program)        # => Entry(model: Coa::Program, column: :program_id, ...)
  #   Coa::FieldCatalog.pairs(:program, agency: 'GSA', active_only: true)
  #   # => [["P100", "Short name"], ...]  (code, name), in code order
  module FieldCatalog
    # name_column is the label AIM shows beside a code; Billing labels by
    # long_name whatever it is.
    Entry = Data.define(:model, :column, :agency_scoped, :name_column) do
      # The whole list for an agency (the agency is ignored for a list that
      # is not per agency).
      def scope(agency)
        agency_scoped ? model.where(agency_id: agency) : model.all
      end

      def active_column? = model.column_names.include?('active')
    end

    def self.entry(model, column, agency_scoped, name_column = :short_name)
      Entry.new(model: model, column: column, agency_scoped: agency_scoped, name_column: name_column)
    end
    private_class_method :entry

    FIELDS = {
      unit: entry(Coa::Unit, :unit_id, true),
      fund: entry(Coa::Fund, :fund_id, false),
      object: entry(Coa::Object, :object_id, false),
      activity: entry(Coa::Activity, :activity_id, true),
      function: entry(Coa::Function, :function_id, true),
      program: entry(Coa::Program, :program_id, true),
      major_program: entry(Coa::MajorProgram, :major_program_id, true),
      phase: entry(Coa::Phase, :phase_id, true),
      task: entry(Coa::Task, :task_id, true),
      department: entry(Coa::Department, :department_id, true),
      dept_object: entry(Coa::ObjectInference, :agency_object_code, true, :agency_object_name)
    }.freeze

    def self.fetch(field) = FIELDS.fetch(field.to_sym)

    # [[code, name], ...] for a field. +scope+ replaces the list's own
    # (Billing narrows objects to an agency's through object_inferences);
    # +name+ defaults to the entry's name column and +order+ to its code
    # column; +active_only+ drops inactive codes where the table has an
    # active column.
    def self.pairs(field, agency: nil, scope: nil, name: nil, order: nil, active_only: false)
      entry = fetch(field)
      scope ||= entry.scope(agency)
      scope = scope.where(active: true) if active_only && entry.active_column?
      scope.order(order || entry.column).pluck(entry.column, name || entry.name_column)
    end
  end
end
