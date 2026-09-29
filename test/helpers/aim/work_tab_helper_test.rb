# frozen_string_literal: true

require 'test_helper'

module Aim
  # The Invoices tab on My Work and the name badge: shown to people with an
  # AIM queue of their own, with their count filled in after the page draws.
  class WorkTabHelperTest < ActionView::TestCase
    include Aim::AccessHelper
    include Aim::WorkTabHelper

    def current_user = session[:user]
    def current_user_group_names = Set[]

    setup do
      @employee = Employee.where.not(id: Aim::Users.group_employee_ids).order(:id).first || skip('no employee')
      session[:user] = { 'employee_id' => @employee.id.to_s }
    end

    test 'someone on the AIM list gets the Invoices tab, linked to My Queue' do
      Aim::Member.create!(employee_id: @employee.id)

      assert aim_invoices_tab?
      render partial: 'aim/shared/work_tab'

      assert_select 'a.work-tab--invoices[href=?]', aim_my_queue_path, text: /Invoices/
      assert_select 'a[data-aim-counts-url-value=?] span[data-aim-count="my_queue"]', aim_counts_path(scope: 'mine')
    end

    test 'someone not on the AIM list gets no tab' do
      assert_not aim_invoices_tab?
    end

    test 'the name badge starts from the Inbox count and hides at zero' do
      render partial: 'aim/shared/profile_badge', locals: { base: 3 }
      assert_select 'span.inbox-badge[data-aim-count-base="3"]:not([hidden])', text: '3'

      render partial: 'aim/shared/profile_badge', locals: { base: 0 }
      assert_select 'span.inbox-badge[data-aim-count-base="0"][hidden]'
    end
  end
end
