# frozen_string_literal: true

require 'test_helper'

# Email rules and copy recipients can name an Authorization Console, and reach
# the same people a routing step sent to that console would.
class TemplateRecipientAuthorizationTest < ActiveSupport::TestCase
  setup do
    @submission = probation_transfer_requests(:one)
    @template = Forms::Template.create!(name: 'Console Recipient Probe', class_name: 'ProbationTransferRequest',
                                        page_count: 3, page_headers: ['Details'], submission_type: 'database')
  end

  test 'an email rule sent to a console mails whoever holds the authorization' do
    rule = @template.email_steps.create!(trigger_event: 'submit', recipient_type: 'authorization',
                                         authorization_service_type: 'hca_safety')
    holders = Minitest::Mock.new
    holders.expect(:pluck, ['officer@ventura.org', nil], [:email])

    emails = AuthorizationConsole.stub(:approver_ids_for, %w[41 42]) do
      Employee.stub(:where, holders) { rule.resolve_recipient_emails(@submission) }
    end

    assert_equal ['officer@ventura.org'], emails
    assert_equal 'Authorized approver — HCA Safety Officer', rule.recipient_label
    holders.verify
  end

  test 'an email rule sent to a console nobody holds mails no one' do
    rule = @template.email_steps.create!(trigger_event: 'submit', recipient_type: 'authorization',
                                         authorization_service_type: 'hca_safety')

    emails = AuthorizationConsole.stub(:approver_ids_for, []) { rule.resolve_recipient_emails(@submission) }

    assert_empty emails
  end

  test 'a copy recipient sent to a console copies whoever holds the authorization' do
    recipient = @template.copy_recipients.create!(recipient_type: 'authorization', trigger_event: 'submit',
                                                  authorization_service_type: 'cir_location')

    ids = AuthorizationConsole.stub(:approver_ids_for, %w[41 42]) { recipient.resolve_recipient_ids(@submission) }

    assert_equal %w[41 42], ids
    assert_equal 'Authorized approver — CIR Incident Manager (by location)', recipient.recipient_label
  end

  test 'a console recipient needs a console the registry knows' do
    rule = @template.email_steps.build(trigger_event: 'submit', recipient_type: 'authorization')
    recipient = @template.copy_recipients.build(recipient_type: 'authorization', trigger_event: 'submit',
                                                authorization_service_type: 'not_a_console')

    assert_not rule.valid?
    assert_not recipient.valid?
  end
end
