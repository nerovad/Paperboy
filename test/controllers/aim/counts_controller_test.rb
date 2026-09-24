# frozen_string_literal: true

require 'test_helper'

module Aim
  # The counts the sidebar, dashboard and My Queue fill in after drawing.
  class CountsControllerTest < ActionController::TestCase
    tests Aim::CountsController

    setup do
      session[:user] = { 'email' => 'jane@example.com', 'employee_id' => 7 }
      @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    end

    test 'every queue, and mine' do
      Aim::Invoice.create!(batch_id: '4601.C1', state: 'ready_for_approval', actor: 'test', assigned_to: 'Jane',
                           assigned_employee_id: 7, assignment_source: 'folder')
      Aim::Invoice.create!(batch_id: '4601.C2', state: 'needs_review', actor: 'test')

      get :show, format: :json

      body = response.parsed_body
      assert_equal 1, body['my_queue']
      assert_equal 1, body.dig('queues', 'ready_for_approval')
      assert_equal 1, body.dig('queues', 'needs_review')
    end
  end
end
