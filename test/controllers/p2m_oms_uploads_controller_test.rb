#   frozen_string_literal: true

require 'test_helper'

class P2mOmsUploadsControllerTest < ActionController::TestCase
  tests P2m::OmsUploadsController

  test 'shows active uploads and excludes removed uploads in the selected range' do
    sign_in
    active_oms, removed_oms = oms_numbers
    create_upload(active_oms, status: 'ready')
    create_upload(removed_oms, status: 'removed')
    reconciled_ids = nil
    ledger = Object.new
    ledger.define_singleton_method(:reconcile_imported!) do |scope:|
      reconciled_ids = scope.pluck(:oms_number)
      0
    end

    P2m::OmsUploadLedger.stub(:new, ledger) do
      get :index, params: { oms_uploads: { start_date: '2026-08-01', end_date: '2026-08-31' } }
    end

    assert_response :success
    assert_equal [active_oms], reconciled_ids
    assert_select 'td', text: active_oms
    assert_select 'td', text: removed_oms, count: 0
  end

  private

  def create_upload(oms_number, status:)
    P2m::OmsUpload.create!(oms_number: oms_number, mailer_date: Date.new(2026, 8, 21), status: status,
                           validation_status: 'passed', import_status: 'not_started',
                           archive_status: 'queued')
  end

  def oms_numbers
    @oms_numbers ||= begin
      suffix = format('%04d', Process.pid % 10_000)
      ["5178#{suffix}", "5179#{suffix}"]
    end
  end

  def sign_in
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
    @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
  end
end
