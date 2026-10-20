# frozen_string_literal: true

require 'test_helper'

module Aim
  # #170 on the pages: queue rows show how long each has waited, red once
  # stale; the dashboard lists what is stale; a purged invoice says so and
  # cannot be restored.
  class StaleRowsTest < ActionController::TestCase
    tests Aim::InvoicesController

    setup do
      session[:user] = { 'email' => 'aim.staff@example.com', 'employee_id' => 42, 'first_name' => 'Aim', 'last_name' => 'Staff' }
      @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    end

    def waiting(batch_id, days, state: 'needs_review')
      row = Aim::Invoice.create!(batch_id: batch_id, state: state, actor: 'aim_worker', budget_unit: '4601',
                                 vendor_name: 'ACME', invoice_number: batch_id)
      row.events.update_all(created_at: days.days.ago)
      row
    end

    test 'queue rows show how long each has waited, red once stale, nothing on its first day' do
      waiting('OLD', 45)
      waiting('MID', 12)
      waiting('NEW', 0)

      get :index, params: { queue: 'needs_review' }
      assert_select 'tr[title=OLD] span.badge.is-denied', text: '45 days'
      assert_select 'tr[title=MID] span.badge.is-scheduled', text: '12 days'
      assert_select 'tr[title=NEW] span.badge', text: /days?\z/, count: 0
    end

    test 'the AIM # shows on queue rows and the review page, and Search older invoices finds it' do
      row = waiting('NUMBERED', 1)
      other = waiting('OTHER', 1, state: 'rejected')
      other.update_columns(finished_at: 400.days.ago)

      get :index, params: { queue: 'needs_review' }
      assert_select 'tr[title=NUMBERED] td', text: "AIM-#{row.id}"

      get :show, params: { id: 'NUMBERED', queue: 'needs_review' }
      assert_select '.aim-review-heading .aim-handle', text: "AIM-#{row.id}"

      get :index, params: { queue: 'rejected', invoice_number: "aim#{other.id}" }
      assert_equal ['OTHER'], @controller.instance_variable_get(:@invoices).map(&:batch_id)
    end

    test 'a purged invoice says so on its row and its page, and Restore refuses it' do
      row = waiting('PURGED', 0, state: 'deleted')
      row.update_columns(pdf_purged_at: Time.zone.local(2026, 9, 1))

      get :index, params: { queue: 'deleted' }
      assert_select 'tr[title=PURGED] span.badge', text: 'PDF purged'

      get :show, params: { id: 'PURGED', queue: 'deleted' }
      assert_match(/The PDF was purged on September 1, 2026/, response.body)
      assert_select 'button[data-value=restore_to_needs_review]', count: 0

      post :restore, params: { id: 'PURGED', queue: 'deleted', invoice_action: 'restore_to_needs_review', reason: 'x' }
      assert_equal 'Its PDF has been purged, so it cannot be restored.', flash[:alert]
      assert_equal 'deleted', row.reload.state
    end
  end

  class StaleDashboardTest < ActionController::TestCase
    tests Aim::DashboardController

    test 'the dashboard lists stale invoices by queue and owner' do
      session[:user] = { 'email' => 'p1@example.com', 'employee_id' => 1 }
      @controller.define_singleton_method(:current_user_group_names) { Set['aim_admin'] }
      @controller.helpers.define_singleton_method(:can_access_app?) { |*| true }
      row = Aim::Invoice.create!(batch_id: 'STUCK', state: 'failed', actor: 'aim_worker', budget_unit: '4601', agency: 'GSA')
      row.events.update_all(created_at: 40.days.ago)

      get :index
      assert_response :success
      assert_select '.aim-stale-panel tr', text: /Failed\s*Shared queue\s*1\s*40 days/
    end
  end
end
