# frozen_string_literal: true

require 'test_helper'

class InboxNotificationMailerTest < ActionMailer::TestCase
  # Stands in for an Employee row. The real table lives in GSABSS, which the
  # test suite reads but never writes, so the lookup is stubbed instead.
  EmployeeDouble = Struct.new(:first_name, :email)

  test 'pending_approval addresses the approver and names the form' do
    submission = probation_transfer_requests(:one)

    mail = with_approver(EmployeeDouble.new('Dana', 'dana@ventura.org')) do
      deliver(submission)
    end

    assert_equal ['dana@ventura.org'], mail.to
    assert_match(/\AAwaiting your approval: /, mail.subject)
    assert_match 'Dana', mail.body.encoded
  end

  test 'pending_approval links to the inbox and to settings' do
    submission = probation_transfer_requests(:one)

    mail = with_approver(EmployeeDouble.new('Dana', 'dana@ventura.org')) do
      deliver(submission)
    end

    assert_match '/inboxqueue', mail.body.encoded
    assert_match '/settings', mail.body.encoded
  end

  test 'pending_approval sends nothing when the approver has no email' do
    submission = probation_transfer_requests(:one)

    mail = with_approver(EmployeeDouble.new('Dana', nil)) { deliver(submission) }

    assert_instance_of ActionMailer::Base::NullMail, mail
  end

  test 'pending_approval sends nothing when the approver is unknown' do
    submission = probation_transfer_requests(:one)

    mail = with_approver(nil) { deliver(submission) }

    assert_instance_of ActionMailer::Base::NullMail, mail
  end

  test 'pending_approval sends nothing when the submission has gone away' do
    mail = with_approver(EmployeeDouble.new('Dana', 'dana@ventura.org')) do
      InboxNotificationMailer.pending_approval('ProbationTransferRequest', -1, nil, '4821').message
    end

    assert_instance_of ActionMailer::Base::NullMail, mail
  end

  test 'pending_approval sends nothing for an unresolvable form class' do
    mail = with_approver(EmployeeDouble.new('Dana', 'dana@ventura.org')) do
      InboxNotificationMailer.pending_approval('NoSuchFormPlease', 1, nil, '4821').message
    end

    assert_instance_of ActionMailer::Base::NullMail, mail
  end

  private

  def with_approver(employee, &block)
    Employee.stub(:find_by, employee, &block)
  end

  # step_id is nil here: the arrival hook passes a real step, but the mail must
  # still render when the step row has since been edited away.
  def deliver(submission)
    InboxNotificationMailer.pending_approval(submission.class.name, submission.id, nil, '4821').message
  end
end
