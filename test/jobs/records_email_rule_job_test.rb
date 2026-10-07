# frozen_string_literal: true

require 'test_helper'
require_relative '../support/records_email_helpers'

class RecordsEmailRuleJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper
  include RecordsEmailHelpers

  Owner = Struct.new(:email, :first_name, keyword_init: true)

  setup do
    vehicle('V1', 'GSA', pacific(2025, 1, 1, 12))
    vehicle('V2', 'HCA', pacific(2025, 1, 2, 12))
    vehicle('V3', 'GSA', pacific(2026, 6, 1, 12))
  end

  def rule
    @rule ||= email_rule.tap(&:save!)
  end

  def run_rule(editor: true, county: %w[gsa@ventura.org], **options)
    permissions = Object.new
    permissions.define_singleton_method(:can_edit_record_table?) { |_table| editor }

    with_county_employees(*county) do
      RecordsEmailContact.find_or_create_by!(table_slug: 'fleet', column_name: 'agency', match_value: 'GSA',
                                             email: 'gsa@ventura.org')
      Submitter.stub(:resolve, Owner.new(email: 'owner@ventura.org', first_name: 'Owner')) do
        EmployeePermissions.stub(:new, permissions) { RecordsEmailRuleJob.perform_now(rule.id, **options) }
      end
    end
  end

  test "emails each agency's contacts their own vehicles as a CSV, and the owner the rest" do
    assert_emails(2) { run_rule }

    to_gsa, to_owner = ActionMailer::Base.deliveries.last(2)
    assert_equal ['gsa@ventura.org'], to_gsa.to
    assert_equal ['owner@ventura.org'], to_gsa.reply_to
    assert_equal 'Fleet Vehicles: Out of compliance (1)', to_gsa.subject
    assert_includes to_gsa.html_part.body.to_s, 'need their locations updated'

    csv = to_gsa.attachments.first.body.to_s
    assert_match(/\Afleet-.*\.csv\z/, to_gsa.attachments.first.filename)
    assert_includes csv, 'V1'
    assert_not_includes csv, 'V2'
    assert_not_includes csv, 'V3'

    assert_equal ['owner@ventura.org'], to_owner.to
    assert_includes to_owner.attachments.first.body.to_s, 'V2'
    assert_includes to_owner.html_part.body.to_s, 'Nobody is listed as a contact'

    assert_equal [%w[gsa@ventura.org GSA], ['owner@ventura.org', nil]],
                 rule.deliveries.order(:id).pluck(:recipients, :group_value)
  end

  test 'sends nothing once no vehicle meets the rule' do
    FleetVehicle.update_all(updated_at: pacific(2026, 6, 1, 12))

    assert_no_emails { run_rule }
    assert_empty rule.deliveries
  end

  test 'pauses the rule, and sends no rows, once the owner loses the edit grant' do
    assert_emails(1) { run_rule(editor: false) }

    mail = ActionMailer::Base.deliveries.last
    assert_equal ['owner@ventura.org'], mail.to
    assert_empty mail.attachments
    assert_not rule.reload.enabled?
  end

  test 'a paused rule runs only when asked to by hand' do
    rule.update!(enabled: false)

    assert_no_emails { run_rule }
    assert_emails(2) { run_rule(manual: true) }
  end
end
