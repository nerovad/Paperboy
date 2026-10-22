# frozen_string_literal: true

require 'test_helper'

module Aim
  # The revamped dashboards and the Help page (#131).
  module DashboardSession
    def sign_in(employee_id, *groups)
      session[:user] = { 'email' => "p#{employee_id}@example.com", 'employee_id' => employee_id }
      @controller.define_singleton_method(:current_user_group_names) { Set.new(groups) }
      @controller.helpers.define_singleton_method(:can_access_app?) { |*| true }
    end

    def ready(batch, **attributes)
      Aim::Invoice.create!({ batch_id: batch, state: 'ready_for_approval', actor: 'test', budget_unit: '4601', agency: 'GSA',
                             document_type: 'Invoice', vendor_name: 'ACME', invoice_number: batch }.merge(attributes))
    end
  end

  class DashboardRevampTest < ActionController::TestCase
    include DashboardSession

    tests Aim::DashboardController

    test 'AIM Admins see what needs attention, today, and the oldest waiting' do
      sign_in 1, 'aim_admin'
      ready('4601.Q1', manual_entry: true)
      Aim::Invoice.create!(batch_id: '4601.Q2', state: 'needs_review', review_reason: 'duplicate', actor: 'test', budget_unit: '4601')

      get :index

      assert_response :success
      assert_select '.aim-attention__tile', text: /1\s*Possible duplicates/
      assert_select '.aim-attention__tile', text: /1\s*Manual data entry/
      assert_select 'a[href=?]', aim_invoices_path(queue: 'needs_review', reason: 'duplicate')
      assert_select '.aim-today', text: /arrived today/
      assert_select 'td a', text: /ACME · 4601.Q1/
    end

    test 'someone with a queue sees their own work' do
      person = Employee.order(:id).first || skip('no employee')
      Aim::Member.create!(employee_id: person.id)
      sign_in person.id
      ready('4601.R1', assigned_employee_id: person.id, first_approved_by: 'boss@example.com', first_approved_at: Time.current)

      get :index

      assert_response :success
      assert_select 'h1', text: 'My AIM'
      assert_select '.aim-attention__tile', text: /1\s*My second approvals/
    end

    test 'nobody without a queue gets a dashboard' do
      sign_in 9
      get :index

      assert_redirected_to aim_root_path
    end
  end

  class FiscalDashboardRevampTest < ActionController::TestCase
    include DashboardSession

    tests Aim::FiscalDashboardController

    test 'Fiscal\'s needs attention and the longest in the Fiscal Queue' do
      sign_in 1, 'aim_admin'
      invoice = Aim::Invoice.create!(batch_id: '4601.S1', state: 'approved', actor: 'test', budget_unit: '4601', agency: 'GSA',
                                     vendor_name: 'ACME', invoice_number: 'S1')
      Aim::FiscalRecord.create!(invoice: invoice, status: 'ready')

      shf = Aim::Invoice.create!(batch_id: '2551.S2', state: 'approved', actor: 'test', budget_unit: '2551', agency: 'SHF')
      Aim::FiscalRecord.create!(invoice: shf, status: 'review')
      Aim::AgencyGroup.for_agency!('SHF')

      get :index

      assert_select '.aim-attention__tile', text: /1\s*Ready to report/
      assert_select 'h2', text: 'By agency group'
    end
  end

  class HelpControllerTest < ActionController::TestCase
    include DashboardSession

    tests Aim::HelpController

    test 'AIM staff read the full How AIM works, and can see what approvers see' do
      sign_in 9, 'aim_admin'
      get :show

      assert_response :success
      %w[start roles groups upload working duplicates fiscal setup alerts faq].each { |id| assert_select "section##{id}" }
      assert_select 'a[href=?]', aim_help_path(for: 'approver'), text: 'What approvers see'

      get :show, params: { for: 'approver' }
      assert_select 'h1', text: 'How to approve invoices'
    end

    test 'someone who only approves gets How to approve, not the full guide' do
      sign_in 9
      get :show

      assert_response :success
      assert_select 'h1', text: 'How to approve invoices'
      assert_select 'section#setup', count: 0
      assert_select 'nav a.nav-link', text: 'How AIM works', count: 0
    end

    # Every screenshot the page names is in git (#144): .gitignore drops PNGs
    # unless a folder is allowed, and a missing one just vanishes from the page.
    test 'every Help screenshot is there and tracked' do
      view = Rails.root.join('app/views/aim/help/show.html.erb').read
      names = view.scan(/aim_help_shot\('([a-z_]+)'/).flatten
      approver = Rails.root.join('app/views/aim/help/approver.html.erb').read.scan(/aim_help_shot\('([a-z_]+)'/).flatten
      tracked = `git -C #{Rails.root} ls-files app/assets/images/aim/help`.lines.map { |line| File.basename(line.strip, '.png') }

      assert_operator names.size, :>=, 6
      assert_empty (names + approver) - tracked, "Help screenshots not in git: #{((names + approver) - tracked).join(', ')}"

      sign_in 9, 'aim_admin'
      get :show
      assert_select 'figure.aim-help__shot img', names.size
    end
  end
end
