# frozen_string_literal: true

require 'test_helper'

# How a pile of per-column RecordEdit rows is turned back into the saves a
# person made. Rows are written here directly rather than through an update, so
# a test can place two of them a controlled distance apart.
module Forms
  class EditTrailTest < ActiveSupport::TestCase
    fixtures :creative_job_requests

    setup do
      @record = creative_job_requests(:one)
    end

    def write(column, old_value, new_value, at:, actor_id: '5001', actor_name: 'Dana Reyes',
              record_id: @record.id, action: 'update')
      RecordEdit.create!(record_type: @record.class.name, record_id: record_id,
                         table_slug: 'creative_job_requests', column_name: column,
                         old_value: old_value, new_value: new_value, action: action,
                         changed_by_id: actor_id, changed_by_name: actor_name, created_at: at)
    end

    test 'columns written in one save read as a single entry' do
      now = Time.current
      write('job_title', 'Old', 'New', at: now)
      write('location', 'Oxnard', 'Camarillo', at: now + 0.2)

      entries = Forms::EditTrail.for(@record)

      assert_equal 1, entries.size
      assert_equal %w[job_title location], entries.first.changes.map(&:column).sort
      assert_equal 'Dana Reyes', entries.first.actor_name
    end

    test 'saves far enough apart stay separate entries' do
      now = Time.current
      write('job_title', 'Old', 'New', at: now)
      write('location', 'Oxnard', 'Camarillo', at: now + 30)

      assert_equal 2, Forms::EditTrail.for(@record).size
    end

    test 'two people editing at the same moment are not merged' do
      now = Time.current
      write('job_title', 'Old', 'New', at: now, actor_id: '5001', actor_name: 'Dana Reyes')
      write('location', 'Oxnard', 'Camarillo', at: now + 0.2, actor_id: '5002', actor_name: 'Sam Ortiz')

      entries = Forms::EditTrail.for(@record)

      assert_equal 2, entries.size
      assert_equal %w[5001 5002], entries.map(&:actor_id)
    end

    test 'entries read oldest first, the way the status timeline does' do
      now = Time.current
      write('job_title', 'First', 'Second', at: now - 60)
      write('job_title', 'Second', 'Third', at: now)

      values = Forms::EditTrail.for(@record).map { |entry| entry.changes.first.new_value }

      assert_equal %w[Second Third], values
    end

    test 'a column with no form field behind it falls back to its humanized name' do
      write('job_title', 'Old', 'New', at: Time.current)

      assert_equal 'Job title', Forms::EditTrail.for(@record).first.changes.first.label
    end

    test 'an emptied field reads as empty rather than as a blank gap' do
      write('location', 'Oxnard', nil, at: Time.current)

      assert_equal Forms::AuditValue::EMPTY, Forms::EditTrail.for(@record).first.changes.first.new_value
    end

    test 'a row being added never merges with an edit made just after it' do
      now = Time.current
      write('job_title', nil, 'New', at: now, action: 'create')
      write('job_title', 'New', 'Newer', at: now + 1)

      assert_equal %w[create update], Forms::EditTrail.for(@record).map(&:action)
    end

    test 'a log spanning a table keeps two rows edited at once apart' do
      now = Time.current
      write('job_title', 'Old', 'New', at: now)
      write('job_title', 'Old', 'New', at: now + 0.2, record_id: @record.id + 1000)

      rows = RecordEdit.where(record_type: @record.class.name)
      entries = Forms::EditTrail.for_rows(@record.class, rows)

      assert_equal [@record.id, @record.id + 1000], entries.map(&:record_id)
    end

    test 'a record nobody has edited has no entries' do
      assert_empty Forms::EditTrail.for(@record)
    end
  end
end
