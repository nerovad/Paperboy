# frozen_string_literal: true

require 'test_helper'

module Aim
  # The Fiscal Dashboard (#131): a card per Fiscal list, notes, latest reports;
  # Fiscal and AIM Admins only.
  class FiscalDashboardControllerTest < ActionController::TestCase
    tests Aim::FiscalDashboardController

    def as_groups(*names)
      @controller.define_singleton_method(:current_user_group_names) { Set.new(names) }
      @controller.helpers.define_singleton_method(:can_access_app?) { |*| true }
    end

    setup { session[:user] = { 'email' => 'fiscal@example.com', 'employee_id' => 42 } }

    test 'a card per Fiscal list, with notes and the latest reports' do
      as_groups 'aim_admin'
      invoice = Aim::Invoice.create!(batch_id: '4641.DB-1', state: 'approved', actor: 'test', budget_unit: '4641',
                                     agency: 'GSA', manual_entry: true, invoice_total: 12)
      Aim::FiscalRecord.create!(invoice: invoice)

      get :index

      assert_response :success
      Aim::FiscalRecord::STATUSES.each { |status| assert_select '[data-aim-count=?]', "fiscal_#{status}" }
      assert_select '.aim-dashboard-note', text: /1 need data entry/
    end

    test 'nobody else gets in' do
      as_groups
      get :index

      assert_redirected_to aim_root_path
    end
  end
end
