# frozen_string_literal: true

require 'test_helper'

# A form's four emails. Nothing saved means the defaults; a saved part wins and
# a blank part falls back, so a form can reword just the subject.
module Forms
  class TemplateEmailTest < ActiveSupport::TestCase
    setup do
      @submission = probation_transfer_requests(:one)
      @template = Forms::Template.create!(name: 'Probation Email Probe', class_name: 'ProbationTransferRequest',
                                          page_count: 3, page_headers: ['Details'], submission_type: 'database')
    end

    test 'a form with nothing saved sends the defaults' do
      email = TemplateEmail.for(@submission, :new_submission)

      assert_not email.persisted?
      assert_equal TemplateEmail.default_subject('new_submission'), email.effective_subject
      assert_includes email.render_body(@submission), 'has been submitted'
    end

    test 'a saved subject wins and a blank body falls back to the default' do
      @template.emails.create!(kind: 'status_changed', subject: 'Moved: {{reference}}')

      email = TemplateEmail.for(@submission, 'status_changed')

      assert_equal "Moved: #{Forms::Reference.reference_for(@submission)}", email.render_subject(@submission)
      assert_equal TemplateEmail.default_body('status_changed'), email.effective_body
    end

    test 'a form has one email of each kind' do
      @template.emails.create!(kind: 'field_edited', subject: 'One')

      assert_not @template.emails.build(kind: 'field_edited').valid?
      assert_not @template.emails.build(kind: 'nonsense').valid?
    end

    test 'the form builder stores only what differs from the default' do
      save_emails(
        'new_submission' => { subject: 'CIR: {{field.incident_type}}', body: TemplateEmail.default_body('new_submission') },
        'field_edited' => { subject: TemplateEmail.default_subject('field_edited'), body: '' }
      )

      assert_equal ['new_submission'], @template.emails.reload.map(&:kind)
      assert_equal 'CIR: {{field.incident_type}}', @template.emails.sole.subject
      assert_nil @template.emails.sole.body
    end

    test 'emptying a customized email in the form builder returns it to the default' do
      @template.emails.create!(kind: 'awaiting_approval', subject: 'Custom')

      save_emails('awaiting_approval' => { subject: '', body: '' })

      assert_empty @template.emails.reload
    end

    private

    def save_emails(form_emails)
      controller = FormTemplatesController.new
      controller.params = ActionController::Parameters.new(form_emails: form_emails)
      controller.send(:save_form_emails, @template)
    end
  end
end
