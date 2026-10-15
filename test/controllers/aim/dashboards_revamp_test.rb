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

      get :index

      assert_select '.aim-attention__tile', text: /1\s*Ready to report/
    end
  end

  class HelpControllerTest < ActionController::TestCase
    include DashboardSession

    tests Aim::HelpController

    test 'anyone signed in reads how AIM works' do
      sign_in 9
      get :show

      assert_response :success
      %w[start roles groups upload working duplicates fiscal setup alerts faq].each { |id| assert_select "section##{id}" }
    end
  end
end
