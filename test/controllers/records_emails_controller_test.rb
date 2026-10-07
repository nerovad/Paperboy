# frozen_string_literal: true

require 'test_helper'
require_relative '../support/records_email_helpers'

# Everything behind the grid's Email dialog sends a table's rows to other
# people, so it takes the edit grant, and only county employees receive.
class RecordsEmailsControllerTest < ActionController::TestCase
  include ActionMailer::TestHelper
  include RecordsEmailHelpers

  RULE = { label: 'Out of compliance', column_name: 'updated_at', operator: 'on_or_before', value: '2025-12-15',
           message: 'The following vehicles are out of compliance and need their locations updated',
           split_column: 'agency', recipients: 'ignored@ventura.org', frequency: 'weekly', day_of_week: '1',
           time_of_day: '07:00' }.freeze

  setup do
    vehicle('V1', 'GSA', pacific(2025, 1, 1, 12))
    vehicle('V2', 'HCA', pacific(2025, 1, 2, 12))
  end

  test 'someone who can open the table but not edit it cannot email it' do
    @controller = RecordsEmailsController.new
    sign_in(record_view: %w[fleet])

    with_county_employees('a@ventura.org') do
      assert_no_emails { post :create, params: { slug: 'fleet', email: { recipients: 'a@ventura.org' } } }
    end
    assert_redirected_to root_path
  end

  test 'sends the view on screen to county employees as a CSV' do
    @controller = RecordsEmailsController.new
    sign_in(record_view: %w[fleet], record_edit: %w[fleet])

    with_county_employees('a@ventura.org') do
      assert_emails(1) do
        post :create, params: { slug: 'fleet', email: { recipients: 'A@ventura.org', note: 'Please review' },
                                view: { filter_agency: 'GSA' } }
      end
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal ['a@ventura.org'], mail.to
    assert_equal ['employee@example.com'], mail.reply_to
    assert_includes mail.html_part.body.to_s, 'Please review'
    assert_includes mail.attachments.first.body.to_s, 'V1'
    assert_not_includes mail.attachments.first.body.to_s, 'V2'
    assert_equal 1, RecordsEmailDelivery.for_table('fleet').last.row_count
    assert_redirected_to records_table_path('fleet', filter_agency: 'GSA', email: 'open')
  end

  test 'refuses an address that is not a county employee' do
    @controller = RecordsEmailsController.new
    sign_in(record_view: %w[fleet], record_edit: %w[fleet])

    with_county_employees('a@ventura.org') do
      assert_no_emails do
        post :create, params: { slug: 'fleet', email: { recipients: 'a@ventura.org, someone@gmail.com' } }
      end
    end
    assert_match(/someone@gmail.com is not a county employee/, flash[:alert])
  end

  test 'an editor adds a rule that splits by agency, and becomes its owner' do
    @controller = RecordsEmailRulesController.new
    sign_in(record_view: %w[fleet], record_edit: %w[fleet])

    assert_difference -> { RecordsEmailRule.count }, 1 do
      post :create, params: { slug: 'fleet', rule: RULE }
    end

    rule = RecordsEmailRule.last
    assert_equal ['1', 'agency', nil], [rule.employee_id, rule.split_column, rule.recipients]
    assert_operator rule.next_run_at, :>, Time.current
  end

  test 'a viewer cannot add, pause or delete a rule' do
    @controller = RecordsEmailRulesController.new
    sign_in(record_view: %w[fleet])
    rule = email_rule.tap(&:save!)

    assert_no_difference -> { RecordsEmailRule.count } do
      post :create, params: { slug: 'fleet', rule: RULE }
      delete :destroy, params: { slug: 'fleet', id: rule.id }
    end
    patch :toggle, params: { slug: 'fleet', id: rule.id }
    assert_predicate rule.reload, :enabled?
  end

  test 'send now queues the rule even when it is paused' do
    @controller = RecordsEmailRulesController.new
    sign_in(record_view: %w[fleet], record_edit: %w[fleet])
    rule = email_rule(enabled: false).tap(&:save!)

    assert_enqueued_with(job: RecordsEmailRuleJob, args: [rule.id, { manual: true }]) do
      post :deliver, params: { slug: 'fleet', id: rule.id }
    end
  end

  test 'an editor adds several contacts for one agency; outsiders are refused' do
    @controller = RecordsEmailContactsController.new
    sign_in(record_view: %w[fleet], record_edit: %w[fleet])

    with_county_employees('a@ventura.org', 'b@ventura.org') do
      post :create, params: { slug: 'fleet', contact: { column_name: 'agency', match_value: 'GSA',
                                                        emails: 'a@ventura.org, b@ventura.org, x@gmail.com' } }
    end

    assert_equal %w[a@ventura.org b@ventura.org], RecordsEmailContact.for_table('fleet').pluck(:email)
    assert_match(/x@gmail.com is not a county employee/, flash[:alert])
  end

  private

  def sign_in(record_view: [], record_edit: [])
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
    view_keys = record_view.to_set
    edit_keys = record_edit.to_set
    @controller.define_singleton_method(:current_user_group_names) { Set.new }
    @controller.define_singleton_method(:current_user_record_view_permission_keys) { view_keys }
    @controller.define_singleton_method(:current_user_record_edit_permission_keys) { edit_keys }
    @controller.define_singleton_method(:current_user_dropdown_permissions) { Set.new }
  end
end
