# frozen_string_literal: true

require 'test_helper'

# The edit trail on a form with no status workflow at all. CreativeJobRequest
# has no status column, no routing and no subscribers, so this exercises
# AuditableEdits on its own; TrackableStatusEditAuditTest covers the same trail
# on a status-tracked form, where a capture also mails whoever follows edits.
class AuditableEditsTest < ActiveSupport::TestCase
  fixtures :creative_job_requests

  setup do
    @record = creative_job_requests(:one)
  end

  def audit_rows = RecordEdit.for_row(@record).to_a

  test 'a form with no status workflow is audited all the same' do
    assert_difference -> { audit_rows.size }, 1 do
      @record.update!(job_title: 'Banner refresh')
    end

    row = audit_rows.find { |edit| edit.column_name == 'job_title' }

    assert_equal 'MyString', row.old_value
    assert_equal 'Banner refresh', row.new_value
    assert_equal 'CreativeJobRequest', row.record_type
  end

  test 'one audit row per column that actually moved' do
    assert_difference -> { audit_rows.size }, 2 do
      @record.update!(job_title: 'Banner refresh', location: 'Camarillo')
    end

    assert_equal %w[job_title location], audit_rows.map(&:column_name).sort
  end

  test 'writing the same value again audits nothing' do
    assert_no_difference -> { audit_rows.size } do
      @record.update!(job_title: @record.job_title)
    end
  end

  test 'the trail names whoever was signed in' do
    Current.set(user: { 'employee_id' => '5001', 'first_name' => 'Dana', 'last_name' => 'Reyes' }) do
      @record.update!(location: 'Camarillo')
    end

    row = audit_rows.find { |edit| edit.column_name == 'location' }

    assert_equal '5001', row.changed_by_id
    assert_equal 'Dana Reyes', row.changed_by_name
  end

  test 'timestamps are not audited' do
    @record.update!(job_title: 'Banner refresh')

    assert_not_includes audit_rows.map(&:column_name), 'updated_at'
  end

  test 'creating a record audits nothing' do
    assert_no_difference -> { RecordEdit.count } do
      CreativeJobRequest.create!(job_title: 'New request', job_id: 'CJR-1')
    end
  end

  test 'a form with no registry slug is stamped with its table name' do
    @record.update!(job_title: 'Banner refresh')

    assert_equal 'creative_job_requests', audit_rows.first.table_slug
  end

  test 'edit_timeline returns this record rows and nobody else' do
    other = creative_job_requests(:two)
    @record.update!(job_title: 'Mine')
    other.update!(job_title: 'Theirs')

    assert_equal ['Mine'], @record.edit_timeline.map(&:new_value)
  end

  # Edit History is not something a form opts into: it appears wherever the Edit
  # button does. That only holds while every editable form keeps a trail, so a
  # new form added without the concern fails here rather than shipping a button
  # that opens on an empty history.
  test 'every form the Edit button can reach keeps an edit trail' do
    models = Dir[Rails.root.join('app/controllers/forms/*_controller.rb')]
             .map { |path| File.basename(path, '_controller.rb') }
             .reject { |name| name == 'base' }
             .filter_map { |name| name.classify.safe_constantize }

    assert_predicate models.size, :positive?, 'no form controllers found -- has the layout changed?'

    unaudited = models.reject { |model| model.include?(AuditableEdits) }.map(&:name)

    assert_empty unaudited, "add `include AuditableEdits` to: #{unaudited.join(', ')}"
  end
end
