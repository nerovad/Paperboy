# frozen_string_literal: true

require 'test_helper'

class P2mOmsUploadsControllerTest < ActionController::TestCase
  tests P2m::OmsUploadsController

  test 'shows active uploads and excludes removed uploads without reconciling' do
    sign_in
    active_oms, removed_oms = oms_numbers
    create_upload(active_oms, status: 'ready', mailer_date: mailer_date)
    create_upload(removed_oms, status: 'removed', mailer_date: mailer_date)

    without_ledger { get :index, params: date_params }

    assert_response :success
    assert_select 'td', text: active_oms
    assert_select 'td', text: removed_oms, count: 0
    assert_select 'button', text: 'Reconcile'
  end

  test 'reconciles the selected range from its own action' do
    sign_in
    active_oms, removed_oms = oms_numbers
    create_upload(active_oms, status: 'ready', mailer_date: mailer_date)
    create_upload(removed_oms, status: 'removed', mailer_date: mailer_date)
    reconciled_ids = nil

    post_reconcile(lambda { |scope:|
      reconciled_ids = scope.pluck(:oms_number)
      1
    })

    assert_response :see_other
    assert_redirected_to p2m_oms_status_path(date_params)
    assert_equal 'Reconciled 1 OMS upload.', flash[:notice]
    assert_equal [active_oms], reconciled_ids
  end

  test 'reports when the selected range needs no reconciliation' do
    sign_in
    post_reconcile(->(**) { 0 })

    assert_redirected_to p2m_oms_status_path(date_params)
    assert_equal 'No OMS uploads needed reconciliation.', flash[:notice]
  end

  test 'retries reconciliation when the ledger deadlocks' do
    sign_in
    attempts = 0

    @controller.stub(:sleep, nil) do
      post_reconcile(lambda { |**|
        attempts += 1
        raise ActiveRecord::Deadlocked if attempts < 3

        2
      })
    end

    assert_equal 3, attempts
    assert_equal 'Reconciled 2 OMS uploads.', flash[:notice]
  end

  test 'rejects a reconcile range that starts after it ends' do
    sign_in
    without_ledger do
      post :reconcile, params: { oms_uploads: { start_date: '2099-02-02', end_date: '2099-02-01' } }
    end

    assert_response :unprocessable_content
    assert_equal 'Start date must be on or before end date.', flash[:alert]
  end

  test 'keeps reconciliation behind the OMS Status grant' do
    sign_in(admin: false)
    without_ledger { post :reconcile, params: date_params }

    assert_redirected_to p2m_root_path
    assert_equal 'Access denied.', flash[:alert]
  end

  private

  def post_reconcile(behavior)
    ledger = Object.new
    ledger.define_singleton_method(:reconcile_imported!, behavior)
    P2m::OmsUploadLedger.stub(:new, ledger) { post :reconcile, params: date_params }
  end

  def without_ledger(&block)
    P2m::OmsUploadLedger.stub(:new, ->(*) { flunk 'OMS Status must not reconcile' }, &block)
  end

  def date_params
    date = mailer_date.strftime('%Y-%m-%d')
    { oms_uploads: { start_date: date, end_date: date } }
  end

  def create_upload(oms_number, status:, mailer_date:)
    P2m::OmsUpload.create!(oms_number: oms_number, mailer_date: mailer_date, status: status,
                           validation_status: 'passed', import_status: 'not_started',
                           archive_status: 'queued')
  end

  def mailer_date
    # Keep this outside the seeded upload history so the selected range only
    # contains rows created by this test.
    @mailer_date ||= Date.new(2099, 1, (Process.pid % 28) + 1)
  end

  def oms_numbers
    @oms_numbers ||= ["5178#{suffix}", "5179#{suffix}"]
  end

  def suffix
    format('%04d', Process.pid % 10_000)
  end

  def sign_in(admin: true)
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
    groups = admin ? ['system_admins'] : ['staff']
    @controller.define_singleton_method(:current_user_group_names) { Set.new(groups) }
    return if admin

    @controller.define_singleton_method(:current_user_application_permission_keys) { ['p2m'] }
    @controller.define_singleton_method(:current_user_feature_permission_keys) { [] }
    @controller.define_singleton_method(:current_user_dropdown_permissions) { [] }
  end
end
