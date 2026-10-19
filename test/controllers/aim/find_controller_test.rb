# frozen_string_literal: true

require 'test_helper'

module Aim
  # Find an invoice (#180): any invoice from one box, wherever it is, never
  # past what the person may already open.
  class FindControllerTest < ActionController::TestCase
    tests Aim::FindController

    def sign_in(*groups, employee_id: 42)
      session[:user] = { 'email' => 'aim.staff@example.com', 'employee_id' => employee_id }
      @controller.define_singleton_method(:current_user_group_names) { Set.new(groups) }
      @controller.helpers.define_singleton_method(:can_access_app?) { |*| true }
    end

    def invoice(batch_id, state: 'needs_review', **attributes)
      defaults = { vendor_name: 'ACME Paper', invoice_number: "N-#{batch_id}", budget_unit: '4601', invoice_total: 10 }
      Aim::Invoice.create!(batch_id: batch_id, state: state, actor: 'aim_worker', **defaults.merge(attributes))
    end

    def found = @controller.instance_variable_get(:@invoices).map(&:batch_id).sort

    test 'the quick box finds across every queue by vendor, invoice #, batch id or amount' do
      sign_in 'aim_admin'
      invoice('A', vendor_name: 'Acme Paper')
      invoice('B', state: 'ready_for_approval', vendor_name: 'ACME Paper')
      invoice('C', state: 'rejected', vendor_name: 'Zenith', invoice_total: 1234.5)
      invoice('D', state: 'exported', vendor_name: 'Other', invoice_number: 'INV-77')

      get :index, params: { q: 'acme' }
      assert_equal %w[A B], found
      assert_select 'tr[title=B] a[href=?]', aim_invoice_path('B', queue: 'ready_for_approval')

      get :index, params: { q: 'acme', where: 'ready_for_approval' }
      assert_redirected_to aim_invoice_path('B', queue: 'ready_for_approval')

      get :index, params: { q: '$1,234.50', where: 'rejected', owner: '' }
      assert_redirected_to aim_invoice_path('C', queue: 'rejected')

      get :index, params: { q: 'INV-7' }
      assert_redirected_to aim_invoice_path('D', queue: 'exported')
    end

    test 'an AIM # opens the invoice; one quick match opens it; filters alone list it' do
      sign_in 'aim_admin'
      row = invoice('ONLY', state: 'failed')

      get :index, params: { q: "aim-#{row.id}" }
      assert_redirected_to aim_invoice_path('ONLY', queue: 'failed')

      get :index, params: { where: 'failed' }
      assert_response :success
      assert_equal %w[ONLY], found
      assert_select 'details.aim-find__more[open]'
    end

    test 'filters: where, owner, unit, received between, manual, possible duplicate, stale' do
      sign_in 'aim_admin'
      sam = invoice('SAM', state: 'ready_for_approval', assigned_to: 'Sam Lee', assignment_source: 'test', manual_entry: true)
      invoice('UNIT', budget_unit: '4602')
      old = invoice('OLD')
      old.update_columns(created_at: Date.new(2026, 3, 15).noon)
      original = invoice('ORIG')
      invoice('DUP', review_reason: 'duplicate', duplicate_of_id: original.id)
      stuck = invoice('STUCK')
      stuck.events.update_all(created_at: 45.days.ago)

      { { owner: 'sam' } => %w[SAM], { budget_unit: '4602' } => %w[UNIT], { manual: '1' } => %w[SAM],
        { duplicate: '1' } => %w[DUP], { stale: '1' } => %w[STUCK],
        { from: '2026-03-01', to: '2026-03-31' } => %w[OLD] }.each do |filter, expected|
        get :index, params: filter
        assert_equal expected, found, filter.inspect
      end
      assert sam
    end

    test 'someone without queue access finds only their own invoices' do
      sign_in employee_id: 7
      invoice('MINE', state: 'ready_for_approval', assigned_employee_id: 7, assigned_to: 'Me', assignment_source: 'test')
      invoice('THEIRS', state: 'ready_for_approval', assigned_employee_id: 8, assigned_to: 'Them', assignment_source: 'test')

      get :index, params: { where: 'ready_for_approval' }
      assert_equal %w[MINE], found
      assert_select 'input[name=owner]', count: 0
    end

    test 'Managing limits the search, and approved ones say which Fiscal list they are on' do
      sign_in 'aim_admin'
      mine = invoice('MINE', state: 'exported')
      invoice('THEIRS', state: 'exported', budget_unit: '4602')
      Aim::FiscalRecord.create!(invoice: mine, status: 'ready')
      groups = Object.new
      groups.define_singleton_method(:invoices) { |_| Aim::Invoice.where(budget_unit: '4601') }
      @controller.helpers.define_singleton_method(:aim_agency_groups) { groups }
      @controller.helpers.define_singleton_method(:aim_managing_groups) { [:picked] }

      get :index, params: { where: 'exported' }
      assert_equal %w[MINE], found
      assert_select 'tr[title=MINE] span.badge', text: 'Fiscal: Report Queue'
    end

    test 'Fiscal finds across every Fiscal list and opens the Fiscal page' do
      sign_in 'aim_admin'
      held = invoice('HELD', state: 'exported', vendor_name: 'Held Co')
      Aim::FiscalRecord.create!(invoice: held, status: 'on_hold', hold_reason: 'x')
      paid = invoice('PAID', state: 'exported', vendor_name: 'Paid Co')
      Aim::FiscalRecord.create!(invoice: paid, status: 'archived', archived_at: 1.day.ago)

      get :fiscal, params: { q: 'co' }
      assert_equal %w[HELD PAID], @controller.instance_variable_get(:@records).map { |r| r.invoice.batch_id }.sort

      get :fiscal, params: { q: 'paid' }
      assert_redirected_to aim_fiscal_invoice_path('PAID')
    end

    test 'Fiscal search is Fiscal only; nothing typed shows nothing' do
      sign_in
      get :fiscal, params: { q: 'x' }
      assert_redirected_to aim_root_path

      sign_in 'aim_admin'
      get :index
      assert_response :success
      assert_empty @controller.instance_variable_get(:@invoices)
      assert_select '.aim-empty-state', text: /Type an AIM #/
    end
  end
end
