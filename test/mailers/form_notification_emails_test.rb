# frozen_string_literal: true

require 'test_helper'

# Every notification about a form speaks in that form's own words: an email
# rule, an inbox notification and a subscription each send the matching
# Forms::TemplateEmail, and each one links back to the submission.
class FormNotificationEmailsTest < ActionMailer::TestCase
  EmployeeDouble = Struct.new(:first_name, :email)

  setup do
    @submission = probation_transfer_requests(:one)
    @template = Forms::Template.create!(name: 'Probation Mail Probe', class_name: 'ProbationTransferRequest',
                                        page_count: 3, page_headers: ['Details'], submission_type: 'database')
    @reference = Forms::Reference.reference_for(@submission)
    @url = "http://example.com/probation_transfer_requests/#{@submission.id}"
  end

  test 'an inbox notification sends the Awaiting Approval email' do
    @template.emails.create!(kind: 'awaiting_approval', subject: 'Approve {{reference}}',
                             body: "Hi {{recipient_first_name}}, over to you.\n\n{{link}}")

    mail = as_employee(EmployeeDouble.new('Dana', 'dana@ventura.org')) do
      InboxNotificationMailer.pending_approval(@submission.class.name, @submission.id, nil, '4821').message
    end

    assert_equal "Approve #{@reference}", mail.subject
    assert_includes mail.body.encoded, 'Hi Dana, over to you.'
    assert_includes mail.body.encoded, @url
  end

  test 'a subscription edit sends the Field Edited email with the changes' do
    @template.emails.create!(kind: 'field_edited', body: "{{changed_by}} changed:\n\n{{changes}}")
    edit = RecordEdit.create!(record_type: @submission.class.name, record_id: @submission.id,
                              table_slug: 'probation_transfer_requests', column_name: 'phone',
                              old_value: '805-555-0100', new_value: '805-555-0199', changed_by_name: 'Lee Park',
                              created_at: Time.current)

    mail = as_employee(EmployeeDouble.new('Dana', 'dana@ventura.org')) do
      FormSubscriptionMailer.activity(@submission.class.name, @submission.id, 'edited', '4821', [edit.id]).message
    end

    assert_equal "Updated: #{FormEmailRenderer.form_name(@submission)} #{@reference}", mail.subject
    assert_includes mail.body.encoded, 'Lee Park changed:'
    assert_includes mail.body.encoded, '805-555-0199'
  end

  test 'an approval email rule sends the Status Changed email' do
    @template.emails.create!(kind: 'status_changed', subject: '{{reference}} is {{status_label}}')
    rule = @template.email_steps.create!(trigger_event: 'approved', recipient_type: 'custom_email',
                                         custom_email: 'ops@ventura.org')

    mail = FormWorkflowMailer.notify(rule.id, @submission.class.name, @submission.id).message

    assert_equal ['ops@ventura.org'], mail.to
    assert_equal "#{@reference} is #{@submission.status_label}", mail.subject
    assert_includes mail.body.encoded, @url
  end

  private

  def as_employee(employee, &block)
    Employee.stub(:find_by, employee, &block)
  end
end
