# frozen_string_literal: true

require 'test_helper'

module Aim
  # Admin -> Agency Groups (#131): AIM Admins make and shape groups; a Group
  # Admin sets its Fiscal people and settings, and nothing else.
  module AgencyGroupsTestSession
    def sign_in(employee_id, *groups)
      session[:user] = { 'email' => "p#{employee_id}@example.com", 'employee_id' => employee_id }
      @controller.define_singleton_method(:current_user_group_names) { Set.new(groups) }
      @controller.helpers.define_singleton_method(:can_access_app?) { |*| true }
    end
  end

  class AgencyGroupsControllerTest < ActionController::TestCase
    include AgencyGroupsTestSession

    tests Aim::AgencyGroupsController

    test 'an AIM Admin makes a custom group and sees every group' do
      sign_in 1, 'aim_admin'
      post :create, params: { name: 'GSA Documents', agency_id: 'GSA' }

      group = Aim::AgencyGroup.find_by!(name: 'GSA Documents')
      assert group.custom
      assert_redirected_to aim_agency_group_path(group)

      get :index
      assert_response :success
      assert_select 'a', text: 'GSA Documents'
    end

    test 'a Group Admin sees only their groups and cannot make one' do
      mine = Aim::AgencyGroup.for_agency!('GSA')
      other = Aim::AgencyGroup.for_agency!('SHF')
      mine.roles.create!(employee_id: 5, role: 'admin')
      sign_in 5

      get :index
      assert_equal [mine], @controller.instance_variable_get(:@groups)

      get :show, params: { id: other.id }
      assert_redirected_to aim_agency_groups_path

      post :create, params: { name: 'Mine now', agency_id: 'GSA' }
      assert_nil Aim::AgencyGroup.find_by(name: 'Mine now')
    end

    test 'a group\'s page shows its units, people and settings' do
      sign_in 1, 'aim_admin'
      group = Aim::AgencyGroup.create!(name: 'Docs', agency_id: 'GSA', custom: true)
      group.units.create!(agency_id: 'GSA', budget_unit: '4641')
      group.roles.create!(employee_id: 42, role: 'fiscal')
      Aim::AgencyGroup.for_agency!('GSA').coverages.create!(covered_group: group)
      Aim::EnabledUnit.create!(agency_id: 'GSA')
      get :show, params: { id: group.id }

      assert_response :success
      assert_select 'input[type=checkbox][name=?][value=?][checked]', 'units[]', '4641'
      assert_select '.aim-page-subtitle', text: /Fiscal also done by GSA/

      get :show, params: { id: group.id, tab: 'roles' }
      assert_select 'td', text: 'Fiscal'

      get :show, params: { id: group.id, tab: 'settings' }
      assert_select 'input[name=?]', 'covered_group_ids[]'
    end

    test 'nobody else gets in' do
      sign_in 9
      get :index

      assert_redirected_to aim_root_path
    end

    test 'only a custom group can be deleted, and its BUs go back' do
      sign_in 1, 'aim_admin'
      agency = Aim::AgencyGroup.for_agency!('GSA')
      custom = Aim::AgencyGroup.create!(name: 'Docs', agency_id: 'GSA', custom: true)
      custom.units.create!(agency_id: 'GSA', budget_unit: '4641')

      delete :destroy, params: { id: agency.id }
      assert Aim::AgencyGroup.exists?(agency.id)

      delete :destroy, params: { id: custom.id }
      assert_not Aim::AgencyGroup.exists?(custom.id)
      assert_equal 0, Aim::AgencyGroupUnit.count
    end
  end

  class AgencyGroupUnitsControllerTest < ActionController::TestCase
    include AgencyGroupsTestSession

    tests Aim::AgencyGroupUnitsController

    test 'ticking units moves them into the custom group, leaving others\' alone' do
      sign_in 1, 'aim_admin'
      units = Coa::Unit.where(agency_id: 'GSA', active: true).distinct.order(:unit_id).limit(3).pluck(:unit_id)
      skip 'need three GSA units in the COA' if units.size < 3
      group = Aim::AgencyGroup.create!(name: 'Docs', agency_id: 'GSA', custom: true)
      other = Aim::AgencyGroup.create!(name: 'Other', agency_id: 'GSA', custom: true)
      other.units.create!(agency_id: 'GSA', budget_unit: units[2])

      patch :update, params: { id: group.id, units: units + ['9999'] }

      assert_equal units.first(2).sort, group.units.pluck(:budget_unit).sort
      assert_equal [units[2]], other.units.pluck(:budget_unit)
    end
  end

  class AgencyGroupUnitsOnAgencyGroupTest < ActionController::TestCase
    include AgencyGroupsTestSession

    tests Aim::AgencyGroupUnitsController

    setup do
      sign_in 1, 'aim_admin'
      @units = Coa::Unit.where(agency_id: 'GSA', active: true).distinct.order(:unit_id).limit(3).pluck(:unit_id)
      skip 'need three GSA units in the COA' if @units.size < 3
      @agency = Aim::AgencyGroup.for_agency!('GSA')
      @all = Coa::Unit.where(agency_id: 'GSA', active: true).distinct.pluck(:unit_id)
    end

    test 'the agency group\'s ticks are AIM\'s Budget Units: unticking stops AIM using a unit' do
      patch :update, params: { id: @agency.id, units: @all - [@units.first] }

      assert_not_includes Aim::Units.new.units_of('GSA'), @units.first
      assert_equal (@all - [@units.first]).sort, Aim::EnabledUnit.where(agency_id: 'GSA').pluck(:unit_id).sort

      patch :update, params: { id: @agency.id, units: @all }
      assert_equal [nil], Aim::EnabledUnit.where(agency_id: 'GSA').pluck(:unit_id), 'every unit is the whole agency'
    end

    test 'units in custom groups stay in use, and ticking one into a custom group turns it on' do
      docs = Aim::AgencyGroup.create!(name: 'Docs', agency_id: 'GSA', custom: true)
      docs.units.create!(agency_id: 'GSA', budget_unit: @units.first)
      patch :update, params: { id: @agency.id, units: [@units.second] }
      assert_equal [@units.first, @units.second].sort, Aim::Units.new.units_of('GSA').sort

      patch :update, params: { id: docs.id, units: [@units.first, @units.third] }
      assert_includes Aim::Units.new.units_of('GSA'), @units.third
      assert_equal [@units.first, @units.third].sort, Aim::AgencyGroups.new.units_of(docs).sort
    end
  end

  class AgencyGroupRolesControllerTest < ActionController::TestCase
    include AgencyGroupsTestSession

    tests Aim::AgencyGroupRolesController

    setup do
      @group = Aim::AgencyGroup.for_agency!('GSA')
      @employee = Employee.order(:id).first || skip('no employee to test with')
    end

    test 'a Group Admin adds Fiscal people but not Group Admins' do
      @group.roles.create!(employee_id: 5, role: 'admin')
      sign_in 5

      post :create, params: { agency_group_id: @group.id, employee_id: @employee.id, role: 'fiscal' }
      assert @group.roles.exists?(employee_id: @employee.id, role: 'fiscal')

      post :create, params: { agency_group_id: @group.id, employee_id: @employee.id, role: 'admin' }
      assert_not @group.roles.exists?(employee_id: @employee.id, role: 'admin')
    end

    test 'an AIM Admin adds a Group Admin' do
      sign_in 1, 'aim_admin'
      post :create, params: { agency_group_id: @group.id, employee_id: @employee.id, role: 'admin' }

      assert @group.roles.exists?(employee_id: @employee.id, role: 'admin')
    end
  end

  class AgencyGroupSettingsControllerTest < ActionController::TestCase
    include AgencyGroupsTestSession

    tests Aim::AgencyGroupSettingsController

    test 'a Group Admin sets the Fiscal settings, but not what the group also processes' do
      group = Aim::AgencyGroup.for_agency!('GSA')
      other = Aim::AgencyGroup.for_agency!('SHF')
      group.roles.create!(employee_id: 5, role: 'admin')
      sign_in 5

      patch :update, params: { id: group.id, export_format: 'tab', export_columns: %w[Title Total],
                               hold_reasons: "Missing MA\n\nWaiting on vendor\n", required_fields: %w[check_number],
                               tag_suggestions: '#INV', covered_group_ids: ['', other.id] }

      group.reload
      assert_equal ['tab', %w[Title Total], ['Missing MA', 'Waiting on vendor'], %w[check_number], ['#INV']],
                   [group.export_format, group.export_column_list, group.hold_reason_list, group.required_field_list,
                    group.tag_suggestion_list]
      assert_empty group.coverages
    end

    test 'an AIM Admin sets what the group also processes' do
      group = Aim::AgencyGroup.for_agency!('GSA')
      other = Aim::AgencyGroup.for_agency!('SHF')
      sign_in 1, 'aim_admin'

      patch :update, params: { id: group.id, export_columns: Aim::FiscalExport::COLUMNS, covered_group_ids: ['', other.id, group.id] }

      assert_equal [other.id], group.coverages.pluck(:covered_group_id)
      assert_nil group.reload.export_columns, 'every column is the default'
    end
  end

  class ManagingControllerTest < ActionController::TestCase
    include AgencyGroupsTestSession

    tests Aim::ManagingController

    test 'a person picks one of their groups, and only theirs' do
      mine = Aim::AgencyGroup.for_agency!('GSA')
      other = Aim::AgencyGroup.for_agency!('SHF')
      mine.roles.create!(employee_id: 5, role: 'fiscal')
      sign_in 5

      patch :update, params: { agency_group_id: mine.id, return_to: '/aim/lookups' }
      assert_redirected_to '/aim/lookups'
      assert_equal mine.id, session[:aim_agency_group_id]

      patch :update, params: { agency_group_id: other.id, return_to: '//evil.example.com' }
      assert_equal mine.id, session[:aim_agency_group_id]
      assert_redirected_to aim_fiscal_path
    end
  end
end
