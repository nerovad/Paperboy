# frozen_string_literal: true

require 'test_helper'

module Aim
  # Group Admins (#131) manage their agency groups' people as a BU Admin
  # manages a BU's, and appoint BU Admins there; nowhere else.
  module GroupAdminSession
    def sign_in(employee_id, *groups)
      session[:user] = { 'email' => "p#{employee_id}@example.com", 'employee_id' => employee_id }
      @controller.define_singleton_method(:current_user_group_names) { Set.new(groups) }
      @controller.helpers.define_singleton_method(:can_access_app?) { |*| true }
    end

    # A custom GSA group of one unit, with employee 5 its Group Admin. AIM
    # uses every GSA unit.
    def docs_group(unit)
      Aim::EnabledUnit.find_or_create_by!(agency_id: 'GSA', unit_id: nil)
      group = Aim::AgencyGroup.create!(name: 'Docs', agency_id: 'GSA', custom: true)
      group.units.create!(agency_id: 'GSA', budget_unit: unit)
      group.roles.create!(employee_id: 5, role: 'admin')
      group
    end
  end

  class GroupAdminBudgetUnitsTest < ActionController::TestCase
    include GroupAdminSession

    tests Aim::MemberBudgetUnitsController

    setup do
      @employee = Employee.where.not(unit: [nil, '']).order(:id).first || skip('no employee with a unit')
      Aim::Member.create!(employee_id: @employee.id)
      docs_group('4641')
      sign_in 5
    end

    test 'appoints a BU Admin in their group\'s units only' do
      post :create, params: { member_id: @employee.id, budget_unit: '4641', bu_admin: '1' }
      assert Aim::UserBudgetUnit.find_by!(employee_id: @employee.id, budget_unit: '4641').bu_admin

      post :create, params: { member_id: @employee.id, budget_unit: '4601', bu_admin: '1' }
      assert_nil Aim::UserBudgetUnit.find_by(employee_id: @employee.id, budget_unit: '4601')
    end

    test 'takes BU Admin away again in their units' do
      row = Aim::UserBudgetUnit.create!(employee_id: @employee.id, budget_unit: '4641', bu_admin: true)
      patch :update, params: { member_id: @employee.id, id: row.id, bu_admin: '0' }

      assert_not row.reload.bu_admin
    end
  end

  class GroupAdminUsersTest < ActionController::TestCase
    include GroupAdminSession

    tests Aim::AdminController

    test 'Users & Queues lists the people of their group\'s units' do
      inside, outside = Employee.where.not(unit: [nil, '']).where.not(last_name: [nil, '']).order(:id).limit(2).to_a
      skip 'need two employees with units' if outside.nil?
      [inside, outside].each { |e| Aim::Member.create!(employee_id: e.id) }
      Aim::UserBudgetUnit.create!(employee_id: inside.id, budget_unit: '4641')
      docs_group('4641')
      sign_in 5

      get :index

      assert_response :success
      ids = @controller.instance_variable_get(:@people).map(&:employee_id)
      assert_includes ids, inside.id
      assert_not_includes ids, outside.id unless outside.unit == '4641'
    end

    test 'a BU Admin with no group still sees their BU\'s people' do
      person = Employee.where.not(unit: [nil, '']).order(:id).first || skip('no employee with a unit')
      Aim::Member.create!(employee_id: person.id)
      Aim::UserBudgetUnit.create!(employee_id: 6, budget_unit: person.unit, bu_admin: true)
      sign_in 6

      get :index

      assert_includes @controller.instance_variable_get(:@people).map(&:employee_id), person.id
    end
  end

  class GroupBuPeopleTest < ActionController::TestCase
    include GroupAdminSession

    tests Aim::AgencyGroupsController

    test 'the BUs & People tab lists who works each unit' do
      person = Employee.where.not(last_name: [nil, '']).order(:id).first || skip('no employee')
      Aim::Member.create!(employee_id: person.id)
      Aim::UserBudgetUnit.create!(employee_id: person.id, budget_unit: '4641', shared_queue: true)
      group = docs_group('4641')
      sign_in 5

      get :show, params: { id: group.id, tab: 'bu_people' }

      assert_response :success
      assert_select 'details#bu-4641:not([open])'

      get :show, params: { id: group.id, tab: 'bu_people', open: '4641' }
      assert_select 'details#bu-4641[open]'
      assert_select 'a[href=?]', aim_member_path(person.id)
      assert_select 'form[action=?]', assign_aim_agency_group_path(group)
    end

    test 'every tab draws' do
      group = docs_group('4641')
      sign_in 1, 'aim_admin'
      Aim::AgencyGroupsController::TABS.each_key do |tab|
        get :show, params: { id: group.id, tab: tab }
        assert_response :success, tab
      end
    end
  end

  class GroupAssignmentTest < ActionController::TestCase
    include GroupAdminSession

    tests Aim::AgencyGroupAssignmentsController

    test 'a Group Admin adds someone to a unit of the group, shared queue on; not to another unit' do
      person = Employee.where.not(unit: '4641').order(:id).first || skip('no employee')
      group = docs_group('4641')
      sign_in 5

      post :create, params: { id: group.id, employee_id: person.id, budget_unit: '4641', shared_queue: '1', bu_admin: '1' }
      row = Aim::UserBudgetUnit.find_by!(employee_id: person.id, budget_unit: '4641')
      assert [row.shared_queue, row.bu_admin].all?
      assert Aim::Member.exists?(employee_id: person.id)

      post :create, params: { id: group.id, employee_id: person.id, budget_unit: '4601' }
      assert_nil Aim::UserBudgetUnit.find_by(employee_id: person.id, budget_unit: '4601')
    end
  end

  class GroupFilterUsersTest < ActionController::TestCase
    include GroupAdminSession

    tests Aim::AdminController

    test 'Users & Queues filters by agency group' do
      inside, outside = Employee.where.not(unit: [nil, '', '4641']).order(:id).limit(2).to_a
      skip 'need two employees' if outside.nil?
      [inside, outside].each { |e| Aim::Member.create!(employee_id: e.id) }
      Aim::UserBudgetUnit.create!(employee_id: inside.id, budget_unit: '4641')
      group = docs_group('4641')
      sign_in 1, 'aim_admin'

      get :index, params: { agency_group: group.id }

      assert_equal [inside.id], @controller.instance_variable_get(:@people).map(&:employee_id)
      assert_select 'select[name=agency_group] option[selected][value=?]', group.id.to_s
    end
  end

  class ManagingQueuesTest < ActionController::TestCase
    include GroupAdminSession

    tests Aim::InvoicesController

    test 'an AIM Admin picking a group sees only its invoices in a queue' do
      docs = docs_group('4641')
      mine = Aim::Invoice.create!(batch_id: '4641.M-1', state: 'needs_review', actor: 'test', budget_unit: '4641', agency: 'GSA')
      Aim::Invoice.create!(batch_id: '4601.M-2', state: 'needs_review', actor: 'test', budget_unit: '4601', agency: 'GSA')
      sign_in 1, 'aim_admin'
      session[:aim_agency_group_id] = docs.id

      get :index, params: { queue: 'needs_review' }

      assert_equal [mine.id], @controller.instance_variable_get(:@invoices).map(&:id)
    end
  end

  class MemberGroupRolesTest < ActionController::TestCase
    include GroupAdminSession

    tests Aim::MemberGroupRolesController

    test 'staff tick Group Admin and Fiscal on a profile; nobody else can' do
      gsa = Aim::AgencyGroup.for_agency!('GSA')
      shf = Aim::AgencyGroup.for_agency!('SHF')
      gsa.roles.create!(employee_id: 77, role: 'fiscal')

      sign_in 5
      patch :update, params: { id: 77, roles: { shf.id => ['admin'] } }
      assert_equal [[gsa.id, 'fiscal']], Aim::AgencyGroupRole.where(employee_id: 77).pluck(:agency_group_id, :role)

      sign_in 1, 'aim_admin'
      patch :update, params: { id: 77, roles: { shf.id => %w[admin fiscal nonsense] } }
      assert_equal [[shf.id, 'admin'], [shf.id, 'fiscal']].sort,
                   Aim::AgencyGroupRole.where(employee_id: 77).pluck(:agency_group_id, :role).sort
    end
  end
end
