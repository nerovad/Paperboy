# frozen_string_literal: true

require 'test_helper'

# The three trails a submission leaves, flattened for a spreadsheet. Rows are
# written straight into the audit tables rather than through a save, so a test
# can place them on either side of the window being asked for.
module Forms
  class AuditExportTest < ActiveSupport::TestCase
    fixtures :creative_job_requests

    setup do
      @record = creative_job_requests(:one)
      @today = Date.current
    end

    def export(sources: Forms::AuditExport::SOURCES.keys, models: [CreativeJobRequest], from: @today, to: @today)
      Forms::AuditExport.new(model_classes: models, sources: sources, start_date: from, end_date: to)
    end

    def write_edit(column: 'job_title', old_value: 'Old', new_value: 'New', at: Time.current)
      RecordEdit.create!(record_type: @record.class.name, record_id: @record.id,
                         table_slug: 'creative_job_requests', column_name: column,
                         old_value: old_value, new_value: new_value,
                         changed_by_id: '5001', changed_by_name: 'Dana Reyes', created_at: at)
    end

    def write_status(at: Time.current)
      StatusChange.create!(trackable: @record, from_status: 'Submitted', to_status: 'Approved',
                           changed_by_id: '5001', changed_by_name: 'Dana Reyes', created_at: at)
    end

    def write_reassignment(at: Time.current)
      TaskReassignment.create!(task: @record, assignment_field: 'approver_id',
                               from_employee_id: '5001', to_employee_id: '5002',
                               reassigned_by_id: '5003', reason: 'Out of office', created_at: at)
    end

    test 'every requested source becomes its own table, in a fixed order' do
      assert_equal %w[edits statuses reassignments], export.tables.map(&:source)
    end

    test 'a source nobody asked for is never queried' do
      write_edit
      write_status

      tables = export(sources: ['statuses']).tables

      assert_equal ['statuses'], tables.map(&:source)
      assert_equal 1, tables.first.rows.size
    end

    test 'a source name that is not one of ours is dropped rather than dispatched' do
      assert_empty export(sources: %w[destroy_all]).tables
    end

    test 'an edit row carries the reference, the field label and both values' do
      write_edit

      row = export(sources: ['edits']).tables.first.rows.first

      assert_equal Forms::Reference.reference_for(@record), row.first
      assert_includes row, 'Job title'
      assert_includes row, 'Old'
      assert_includes row, 'New'
    end

    test 'entries outside the window are left out' do
      write_edit(at: 3.days.ago)
      write_edit(at: Time.current)

      assert_equal 1, export(sources: ['edits']).tables.first.rows.size
    end

    test 'a source with nothing to report is still a table' do
      table = export(sources: ['statuses']).tables.first

      assert_not table.any?
      assert_equal 'Status Change History', table.label
    end

    test 'a table renders as CSV headed by its own columns' do
      write_status

      csv = CSV.parse(export(sources: ['statuses']).tables.first.to_csv)

      assert_equal Forms::AuditExport::HEADERS['statuses'], csv.first
      assert_equal 'Approved', csv.second[csv.first.index('To Status')]
    end

    test 'a reassignment names the field it moved and why' do
      write_reassignment

      row = export(sources: ['reassignments']).tables.first.rows.first

      assert_includes row, 'approver_id'
      assert_includes row, 'Out of office'
    end

    test 'total_rows counts every source together' do
      write_edit
      write_status
      write_reassignment

      assert_equal 3, export.total_rows
    end

    test 'a form the export was not scoped to is not swept in' do
      write_edit

      assert_empty export(sources: ['edits'], models: [ProbationTransferRequest]).tables.first.rows
    end
  end
end
