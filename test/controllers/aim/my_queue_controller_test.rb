# frozen_string_literal: true

require 'test_helper'

module Aim
  # My Queue: only the signed-in person's invoices that are ready for them.
  class MyQueueControllerTest < ActionController::TestCase
    tests Aim::MyQueueController

    setup do
      session[:user] = { 'email' => 'jane@example.com', 'employee_id' => 7 }
      @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    end

    def row(batch_id, state, employee_id)
      Aim::Invoice.create!(batch_id: batch_id, state: state, actor: 'test', assigned_to: 'Someone',
                           assigned_employee_id: employee_id, assignment_source: 'folder')
    end

    test 'lists only my invoices that are ready for approval, with an upload button' do
      mine = row('4601.M1', 'ready_for_approval', 7)
      row('4601.M2', 'needs_review', 7)
      row('4601.M3', 'ready_for_approval', 8)

      get :index

      assert_response :success
      assert_equal [mine.batch_id], @controller.instance_variable_get(:@invoices).map(&:batch_id)
      assert_select 'a[href=?]', new_aim_upload_path, text: 'Upload Invoices'
    end
  end
end
