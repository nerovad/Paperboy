# frozen_string_literal: true

require 'test_helper'

module Aim
  # Shared Queues: the ready, unowned invoices of the BUs you cover.
  class SharedQueuesControllerTest < ActionController::TestCase
    tests Aim::SharedQueuesController

    setup do
      session[:user] = { 'email' => 'jane@example.com', 'employee_id' => 7 }
      @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    end

    def row(batch_id, budget_unit, state: 'ready_for_approval', owner: nil)
      Aim::Invoice.create!(batch_id: batch_id, state: state, actor: 'test', budget_unit: budget_unit,
                           assigned_employee_id: owner, assigned_to: owner && 'Someone',
                           assignment_source: owner && 'folder')
    end

    test 'one group per BU shared queue, only ready invoices nobody owns' do
      row('4601.SQ1', '4601')
      row('4641.SQ2', '4641')
      row('4641.SQ3', '4641', owner: 8)
      row('4641.SQ4', '4641', state: 'needs_review')

      Aim::Users.stub(:shared_budget_units, %w[4601 4641]) { get :index }

      assert_response :success
      coa = Aim::Units.new
      assert_equal(["#{coa.label('4601')} shared queue", "#{coa.label('4641')} shared queue"],
                   @controller.instance_variable_get(:@groups).map(&:first))
      assert_equal(%w[4641.SQ2], @controller.instance_variable_get(:@groups).last.last.map(&:batch_id))
    end

    test 'a BU you do not cover is not shown' do
      row('4601.SQ5', '4601')

      Aim::Users.stub(:shared_budget_units, %w[4641]) { get :index }

      assert_empty @controller.instance_variable_get(:@groups)
    end

    test "an AIM Admin's Shared Queues are their own BUs, not every BU" do
      session[:user] = (session[:user] || {}).merge('employee_id' => 7)
      @controller.define_singleton_method(:current_user_group_names) { Set['aim_admin'] }
      Aim::UserBudgetUnit.create!(employee_id: 7, budget_unit: '4641')
      row('4641.SQ7', '4641')
      row('4621.SQ8', '4621')

      get :index

      batches = @controller.instance_variable_get(:@groups).flat_map(&:last).map(&:batch_id)
      assert_includes batches, '4641.SQ7'
      assert_not_includes batches, '4621.SQ8'
    end
  end
end
