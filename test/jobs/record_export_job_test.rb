# frozen_string_literal: true

require 'test_helper'

class RecordExportJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  Owner = Struct.new(:email, :first_name, keyword_init: true)

  def owner = Owner.new(email: 'owner@example.com', first_name: 'Owner')

  def schedule
    @schedule ||= ScheduledRecordExport.create!(employee_id: '1001', table_slug: 'fleet', frequency: 'daily',
                                                time_of_day: '07:00', view_params: { 'search' => 'ford' })
  end

  def with_access(allowed, &block)
    permissions = Object.new
    permissions.define_singleton_method(:can_access_record_table?) { |_table| allowed }

    Submitter.stub(:resolve, owner) do
      EmployeePermissions.stub(:new, permissions, &block)
    end
  end

  test 'emails the saved view as a CSV while the owner can open the table' do
    with_access(true) do
      assert_emails(1) { RecordExportJob.perform_now(schedule.id) }
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal ['owner@example.com'], mail.to
    assert_equal 1, mail.attachments.size
    assert_match(/\Afleet-.*\.csv\z/, mail.attachments.first.filename)
    assert_predicate schedule.reload, :enabled?
  end

  test 'pauses the schedule, and sends no file, once the owner loses access' do
    with_access(false) do
      assert_emails(1) { RecordExportJob.perform_now(schedule.id) }
    end

    assert_empty ActionMailer::Base.deliveries.last.attachments
    assert_not schedule.reload.enabled?
  end

  test 'a paused schedule does not run' do
    schedule.update!(enabled: false)

    with_access(true) do
      assert_no_emails { RecordExportJob.perform_now(schedule.id) }
    end
  end
end
