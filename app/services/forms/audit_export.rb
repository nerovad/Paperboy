# frozen_string_literal: true

# app/services/forms/audit_export.rb

module Forms
  # The trails a submission leaves behind, flattened into spreadsheets.
  #
  # Three tables answer "what happened to this submission": RecordEdit says
  # which field changed, StatusChange where it moved through the workflow, and
  # TaskReassignment who it was handed to. All three are polymorphic across
  # every form model, so an export is one query per source scoped to the form
  # classes the requester may see — not a query per form.
  #
  # Rows read the way the on-screen trails read; Forms::AuditColumns owns that
  # translation. The raw column name is exported alongside its label anyway,
  # because a spreadsheet is also where somebody reconciles against the database.
  class AuditExport
    # Export key => what the reports page calls it. The key is what a request
    # carries and what the generated CSV is named.
    SOURCES = {
      'edits' => 'Edit History',
      'statuses' => 'Status Change History',
      'reassignments' => 'Reassignment History'
    }.freeze

    HEADERS = {
      'edits' => ['Reference', 'Form', 'Record ID', 'Changed At', 'Changed By', 'Changed By ID',
                  'Field', 'Column', 'Old Value', 'New Value'].freeze,
      'statuses' => ['Reference', 'Form', 'Record ID', 'Changed At', 'Changed By', 'Changed By ID',
                     'From Status', 'To Status', 'Notes'].freeze,
      'reassignments' => ['Reference', 'Form', 'Record ID', 'Reassigned At', 'Assignment Field',
                          'From Employee ID', 'From Employee', 'To Employee ID', 'To Employee',
                          'Reassigned By ID', 'Reassigned By', 'Reason'].freeze
    }.freeze

    class << self
      # The model behind one of the reports page's form_type values — a
      # tableized class name such as "leave_of_absence_forms" — or nil.
      def model_for(form_type)
        template = Forms::Template.all.find { |candidate| candidate.class_name.tableize == form_type.to_s }
        template && model_named(template.class_name)
      end

      # A form is exportable only if its model actually keeps a trail. Status
      # history and reassignments ride on models that are edit-audited too —
      # TrackableStatus includes AuditableEdits — so this one test covers all
      # three sources.
      def auditable?(form_type)
        model = model_for(form_type)
        model.present? && model.include?(AuditableEdits)
      end

      # Resolve only application models; never arbitrary constants.
      def model_named(class_name)
        Rails.application.eager_load! unless Rails.application.config.eager_load

        ApplicationRecord.descendants.find { |model_class| model_class.name == class_name.to_s }
      end
    end

    def initialize(model_classes:, sources:, start_date:, end_date:)
      @columns = Forms::AuditColumns.new(model_classes)
      @sources = SOURCES.keys & Array(sources).map(&:to_s)
      @range = start_date.beginning_of_day..end_date.end_of_day
    end

    def tables
      @tables ||= @sources.filter_map { |source| table_for(source) }
    end

    def total_rows
      tables.sum { |table| table.rows.size }
    end

    private

    # Dispatched by hand rather than by send: the source key arrives from a
    # form post, and a case here means a stray value can only ever be nothing.
    def table_for(source)
      case source
      when 'edits' then build('edits', edit_rows)
      when 'statuses' then build('statuses', status_rows)
      when 'reassignments' then build('reassignments', reassignment_rows)
      end
    end

    def build(source, rows)
      Table.new(source: source, label: SOURCES[source], headers: HEADERS[source], rows: rows)
    end

    def edit_rows
      scope(RecordEdit, :record_type).map do |row|
        type = row.record_type
        [@columns.reference(type, row.record_id), @columns.form_name(type), row.record_id,
         @columns.at(row.created_at), row.changed_by_name, row.changed_by_id,
         @columns.label(type, row.column_name), row.column_name,
         @columns.value(type, row.column_name, row.old_value),
         @columns.value(type, row.column_name, row.new_value)]
      end
    end

    def status_rows
      scope(StatusChange, :trackable_type).map do |row|
        type = row.trackable_type
        [@columns.reference(type, row.trackable_id), @columns.form_name(type), row.trackable_id,
         @columns.at(row.created_at), row.changed_by_name, row.changed_by_id,
         row.from_status, row.to_status, row.notes]
      end
    end

    def reassignment_rows
      records = scope(TaskReassignment, :task_type).to_a
      names = @columns.employee_names(
        records.flat_map { |row| [row.from_employee_id, row.to_employee_id, row.reassigned_by_id] }
      )

      records.map do |row|
        type = row.task_type
        [@columns.reference(type, row.task_id), @columns.form_name(type), row.task_id,
         @columns.at(row.created_at), row.assignment_field,
         row.from_employee_id, names[row.from_employee_id.to_s],
         row.to_employee_id, names[row.to_employee_id.to_s],
         row.reassigned_by_id, names[row.reassigned_by_id.to_s],
         row.reason]
      end
    end

    # Every audit table is the same query with a different name for the column
    # holding the form's class name.
    def scope(model, type_column)
      model.where(type_column => @columns.class_names, :created_at => @range).order(:created_at, :id)
    end
  end
end
