# frozen_string_literal: true

require 'test_helper'

module Aim
  # Fiscal Setup: one sidebar link for Report Templates and Stamp Layouts,
  # shown as tabs across those pages, so the Fiscal menu keeps to daily work.
  class FiscalSetupTest < ActionController::TestCase
    tests Aim::StampLayoutsController

    setup do
      session[:user] = { 'email' => 'fiscal@example.com', 'employee_id' => 42 }
      @controller.define_singleton_method(:current_user_group_names) { Set.new }
      @controller.helpers.define_singleton_method(:can_access_app?) { |*| true }
      Aim::AgencyGroup.for_agency!('GSA').roles.create!(employee_id: 42, role: 'fiscal')
    end

    test 'the Fiscal menu has one Fiscal Setup link, and the setup pages are its tabs' do
      get :index

      assert_response :success
      assert_select '.nav-group a.nav-link', text: 'Fiscal Setup'
      assert_select '.nav-group a.nav-link', text: 'Report Templates', count: 0
      assert_select '.nav-group a.nav-link', text: 'Stamp Layouts', count: 0
      assert_select '.nav-group a.nav-link.active', text: 'Fiscal Setup'
      assert_select '.aim-fiscal-setup-tabs a', text: 'Report Templates'
      assert_select '.aim-fiscal-setup-tabs a.active[aria-current=page]', text: 'Stamp Layouts'
      assert_select '.aim-fiscal-setup-tabs a', text: 'Agency Groups', count: 0
    end
  end
end
