# frozen_string_literal: true

require 'test_helper'

module Aim
  # Email alerts (#131): who would be told what, by group and BU settings;
  # nothing sent unless AIM_EMAIL_ALERTS=on.
  class AlertsTest < ActiveSupport::TestCase
    include ActionMailer::TestHelper

    setup do
      @group = Aim::AgencyGroup.for_agency!('GSA')
      @owner = Employee.where.not(email: [nil, '']).order(:id).first || skip('no employee with an email')
    end

    def waiting(batch, days:, **attributes)
      invoice = Aim::Invoice.create!({ batch_id: batch, state: 'ready_for_approval', actor: 'test', budget_unit: '4601',
                                       agency: 'GSA', document_type: 'Invoice', vendor_name: 'ACME', invoice_number: batch }
                                       .merge(attributes))
      invoice.events.update_all(created_at: days.days.ago)
      invoice
    end

    test 'owners hear about invoices waiting past the group\'s days; a BU can change them' do
      old = waiting('4601.A1', days: 8, assigned_employee_id: @owner.id)
      waiting('4601.A2', days: 3, assigned_employee_id: @owner.id)

      assert_equal [old], Aim::Alerts.new.digests[@owner.id]['owner_past_due']

      Aim::AlertSetting.replace!(@group, '4601', { 'owner_past_due' => { on: true, days: 2 } }, by: 'test')
      assert_equal 2, Aim::Alerts.new.digests[@owner.id]['owner_past_due'].size

      Aim::AlertSetting.replace!(@group, '4601', { 'owner_past_due' => { on: false } }, by: 'test')
      assert_empty Aim::Alerts.new.digests[@owner.id]['owner_past_due']
    end

    test 'BU Admins hear about possible duplicates and old unowned shared-queue invoices' do
      Aim::UserBudgetUnit.create!(employee_id: @owner.id, budget_unit: '4601', bu_admin: true)
      shared = waiting('4601.B1', days: 9)
      duplicate = waiting('4601.B2', days: 0, state: 'needs_review', review_reason: 'duplicate')

      digest = Aim::Alerts.new.digests[@owner.id]
      assert_equal [[shared], [duplicate]], [digest['bu_admin_shared_past_due'], digest['bu_admin_duplicates']]
    end

    test 'nothing is sent unless AIM_EMAIL_ALERTS is on' do
      waiting('4601.C1', days: 8, assigned_employee_id: @owner.id)

      assert_no_emails { Aim::AlertDigestJob.perform_now }

      ENV['AIM_EMAIL_ALERTS'] = 'on'
      assert_emails(1) { Aim::AlertDigestJob.perform_now }
    ensure
      ENV.delete('AIM_EMAIL_ALERTS')
    end

    test 'the digest lists each kind with links' do
      invoice = waiting('4601.D1', days: 8, assigned_employee_id: @owner.id)
      mail = Aim::AlertMailer.digest(@owner.id, { 'owner_past_due' => [invoice.id] })

      assert_equal [@owner.email], mail.to
      assert_match(/Waiting in your queue \(1\)/, mail.text_part.body.to_s)
      assert_includes mail.html_part.body.to_s, invoice.batch_id.split('.').first
    end
  end
end
