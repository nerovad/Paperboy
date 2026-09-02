# frozen_string_literal: true

module Coa
  # Every Chart of Accounts table, in sidebar order.
  #
  # `collection` is the table's route collection name — which is also its ACL
  # feature key, so the sidebar button and the controller behind it are gated
  # by the same string (see AppFeature). `budget_unit` says which of the two
  # sidebar groups it belongs to.
  #
  # This was a pair of private methods on Coa::BaseController until the command
  # palette needed the same list. The palette answers ":" from any app and can
  # call no COA controller, so the list had to leave the one class that could
  # build it. Three surfaces read it now: the sidebar, the row-count overview
  # on the COA index, and the palette.
  module Tables
    ALL = [
      { model: 'Coa::Agency',          label: 'Agency',         collection: 'agencies',          budget_unit: true },
      { model: 'Coa::Division',        label: 'Division',       collection: 'divisions',         budget_unit: true },
      { model: 'Coa::Department',      label: 'Department',     collection: 'departments',       budget_unit: true },
      { model: 'Coa::Unit',            label: 'Unit',           collection: 'units',             budget_unit: true },
      { model: 'Coa::SubUnit',         label: 'Sub Unit',       collection: 'sub_units',         budget_unit: true },
      { model: 'Coa::Activity',        label: 'Activity',       collection: 'activities',        budget_unit: false },
      { model: 'Coa::Function',        label: 'Function',       collection: 'functions',         budget_unit: false },
      { model: 'Coa::Fund',            label: 'Fund',           collection: 'funds',             budget_unit: false },
      { model: 'Coa::MajorProgram',    label: 'Major Programs', collection: 'major_programs',    budget_unit: false },
      { model: 'Coa::Object',          label: 'Object',         collection: 'objects',           budget_unit: false },
      { model: 'Coa::Phase',           label: 'Phase',          collection: 'phases',            budget_unit: false },
      { model: 'Coa::Program',         label: 'Program',        collection: 'programs',          budget_unit: false },
      { model: 'Coa::RevenueSource',   label: 'Revenue Source', collection: 'revenue_sources',   budget_unit: false },
      { model: 'Coa::ObjectInference', label: 'Object Inference', collection: 'object_inferences', budget_unit: false },
      { model: 'Coa::Task',            label: 'Task',           collection: 'tasks',             budget_unit: false }
    ].freeze

    # The two lookup screens above the tables. Each is an ACL feature grant of
    # its own, keyed the same way the tables are, in the shape
    # NavigationCatalog::FEATURE_LINKS reads a link in.
    LOOKUPS = [
      { key: 'billing_lookup',  label: 'Billing Lookup',  route: :coa_billing_lookup_path },
      { key: 'customer_lookup', label: 'Employee Lookup', route: :coa_customer_lookup_path }
    ].freeze

    class << self
      # Model classes are named rather than referenced so this file does not
      # pin fifteen constants at load time; Rails resolves them on demand.
      def models
        ALL.map { |table| table[:model].constantize }
      end

      def find(model_class)
        ALL.find { |table| table[:model] == model_class.name } ||
          raise(KeyError, "#{model_class.name} is not a Chart of Accounts table")
      end

      def collection_for(model_class)
        find(model_class).fetch(:collection)
      end

      def label_for(model_class)
        find(model_class).fetch(:label)
      end

      def budget_unit?(model_class)
        find(model_class).fetch(:budget_unit)
      end
    end
  end
end
