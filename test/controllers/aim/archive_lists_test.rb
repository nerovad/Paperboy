# frozen_string_literal: true

require 'test_helper'

module Aim
  # The finished lists (#169): a recent window by default, and Search the
  # archive over every finished invoice, on the server, capped.
  class ArchiveListsTest < ActionController::TestCase
    tests Aim::InvoicesController

    setup do
      session[:user] = { 'email' => 'aim.staff@example.com', 'employee_id' => 42, 'first_name' => 'Aim', 'last_name' => 'Staff' }
      @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    end

    def finished(batch_id, state: 'rejected', days_ago: 1, **attributes)
      defaults = { vendor_name: 'ACME', invoice_number: 'INV-1', budget_unit: '4601', invoice_total: 10 }
      row = Aim::Invoice.create!(batch_id: batch_id, state: state, actor: 'aim_worker', **defaults.merge(attributes))
      row.update_column(:finished_at, days_ago.days.ago)
      row
    end

    def listed = @controller.instance_variable_get(:@invoices).map(&:batch_id)

    test 'a move into a finished state dates the finish and a restore clears it' do
      row = Aim::Invoice.create!(batch_id: 'F-1', state: 'needs_review', actor: 'aim_worker')
      assert_nil row.finished_at

      row.transition_to!('rejected', actor: 'aim.staff@example.com')
      assert_in_delta Time.current, row.finished_at, 5.seconds

      row.transition_to!('needs_review', actor: 'aim.staff@example.com')
      assert_nil row.finished_at
    end

    test 'a finished list shows the last 30 days unless another window is picked' do
      finished('NEW', days_ago: 2)
      finished('OLD', days_ago: 60)

      get :index, params: { queue: 'rejected' }
      assert_response :success
      assert_equal %w[NEW], listed
      assert_select '.aim-archive select[name=days] option[selected][value="30"]'
      assert_select 'details.aim-archive__search:not([open])'

      get :index, params: { queue: 'rejected', days: '90' }
      assert_equal %w[NEW OLD].sort, listed.sort
    end

    test 'a row the old worker finished without a date is dated by its last change' do
      row = finished('UNDATED', days_ago: 1)
      row.update_columns(finished_at: nil, updated_at: 2.days.ago)
      stale = finished('STALE', days_ago: 1)
      stale.update_columns(finished_at: nil, updated_at: 90.days.ago)

      get :index, params: { queue: 'rejected' }
      assert_equal %w[UNDATED], listed
    end

    test 'the archive search finds old invoices by vendor, number, amount, unit and finish date' do
      finished('ACME-OLD', days_ago: 200, vendor_name: 'Acme Paper', invoice_number: 'A-77', invoice_total: 1234.5)
      finished('OTHER-OLD', days_ago: 200, vendor_name: 'Zenith', invoice_number: 'Z-1', budget_unit: '4602')
      finished('ACME-NEW', days_ago: 1, vendor_name: 'Acme Paper', invoice_number: 'A-78')

      get :index, params: { queue: 'rejected', vendor: 'acme' }
      assert_equal %w[ACME-NEW ACME-OLD].sort, listed.sort
      assert_select 'details.aim-archive__search[open]'
      assert_select '.aim-archive__window', text: /2 invoices from all time/

      get :index, params: { queue: 'rejected', invoice_number: '77' }
      assert_equal %w[ACME-OLD], listed

      get :index, params: { queue: 'rejected', amount: '$1,234.50' }
      assert_equal %w[ACME-OLD], listed

      get :index, params: { queue: 'rejected', budget_unit: '4602' }
      assert_equal %w[OTHER-OLD], listed

      from = 201.days.ago.to_date.iso8601
      to = 199.days.ago.to_date.iso8601
      get :index, params: { queue: 'rejected', from: from, to: to }
      assert_equal %w[ACME-OLD OTHER-OLD].sort, listed.sort
    end

    test 'the search looks in the finished queue picked, by agency, and says what it could not read' do
      finished('GSA-1', state: 'deleted', days_ago: 400, agency: 'GSA')
      finished('HCA-1', state: 'deleted', days_ago: 400, agency: 'HCA')
      finished('REJ-1', state: 'rejected', days_ago: 400, agency: 'GSA')

      get :index, params: { queue: 'deleted', agency: 'GSA' }
      assert_equal %w[GSA-1], listed

      get :index, params: { queue: 'deleted', agency: 'GSA', amount: 'ten dollars', from: 'March' }
      assert_equal %w[GSA-1], listed
      assert_select '.aim-archive__problem', text: /ten dollars is not an amount and March is not a date/
    end

    test 'results are capped with a message' do
      3.times { |index| finished("CAP-#{index}", days_ago: index + 1) }
      original = Aim::ArchiveSearch::CAP
      silence_warnings { Aim::ArchiveSearch.const_set(:CAP, 2) }

      get :index, params: { queue: 'rejected', vendor: 'ACME' }
      assert_equal %w[CAP-2 CAP-1], listed
      assert_select '.aim-archive__problem', text: /Showing the newest 2\. There are more/
    ensure
      silence_warnings { Aim::ArchiveSearch.const_set(:CAP, original) }
    end

    test 'the search keeps to the agency groups picked in Managing' do
      finished('MINE', days_ago: 300, budget_unit: '4601')
      finished('THEIRS', days_ago: 300, budget_unit: '4602')
      groups = Object.new
      groups.define_singleton_method(:invoices) { |_| Aim::Invoice.where(budget_unit: '4601') }
      @controller.helpers.define_singleton_method(:aim_agency_groups) { groups }
      @controller.helpers.define_singleton_method(:aim_managing_groups) { [:picked] }

      get :index, params: { queue: 'rejected', vendor: 'ACME' }
      assert_equal %w[MINE], listed
    end

    test 'a work queue is unchanged: everything in it, no window and no archive search' do
      row = Aim::Invoice.create!(batch_id: 'WORK-OLD', state: 'needs_review', actor: 'aim_worker')
      row.update_columns(updated_at: 400.days.ago, created_at: 400.days.ago)

      get :index, params: { queue: 'needs_review', vendor: 'nobody' }
      assert_equal %w[WORK-OLD], listed
      assert_select '.aim-archive', count: 0
    end
  end

  # Fiscal's Exported and Archived lists window on when Fiscal exported or
  # archived the invoice, and search the same way.
  class FiscalArchiveListsTest < ActionController::TestCase
    tests Aim::FiscalController

    setup do
      session[:user] = { 'email' => 'fiscal@example.com', 'employee_id' => 42 }
      @controller.define_singleton_method(:current_user_group_names) { Set['aim_admin'] }
      @controller.helpers.define_singleton_method(:can_access_app?) { |*| true }
    end

    def record(batch_id, status, days_ago, **attributes)
      invoice = Aim::Invoice.create!(batch_id: batch_id, state: 'exported', actor: 'test', budget_unit: '4641',
                                     vendor_name: 'ACME', invoice_number: batch_id, **attributes)
      stamp = status == 'archived' ? :archived_at : :exported_at
      Aim::FiscalRecord.create!(invoice: invoice, status: status, stamp => days_ago.days.ago)
    end

    def listed = @controller.instance_variable_get(:@records).map { |record| record.invoice.batch_id }

    test 'Exported shows the recent window; the search reaches back' do
      record('X-NEW', 'exported', 3)
      record('X-OLD', 'exported', 120, vendor_name: 'Old Vendor')

      get :index, params: { status: 'exported' }
      assert_response :success
      assert_equal %w[X-NEW], listed

      get :index, params: { status: 'exported', vendor: 'old vendor' }
      assert_equal %w[X-OLD], listed
    end

    test 'Archived windows on the archive date, with an empty window still offering the search' do
      record('A-OLD', 'archived', 45)

      get :index, params: { status: 'archived' }
      assert_empty listed
      assert_select '.aim-empty-state', text: /Nothing here in the last 30 days/
      assert_select 'details.aim-archive__search select[name=status] option', count: 2

      get :index, params: { status: 'archived', days: '90' }
      assert_equal %w[A-OLD], listed
    end

    test 'the working Fiscal lists are unchanged' do
      record('R-OLD', 'review', 400)

      get :index, params: { status: 'review' }
      assert_equal %w[R-OLD], listed
      assert_select '.aim-archive', count: 0
    end
  end
end
