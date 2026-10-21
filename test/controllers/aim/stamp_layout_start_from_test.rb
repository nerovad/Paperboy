# frozen_string_literal: true

require 'test_helper'

module Aim
  # Start from (#229): a group's designer loads the default, the built-in
  # stamp or another group's layout; nothing is saved until Save.
  class StampLayoutStartFromTest < ActionController::TestCase
    tests Aim::StampLayoutsController

    setup do
      session[:user] = { 'email' => 'fiscal@example.com', 'employee_id' => 42 }
      @controller.define_singleton_method(:current_user_group_names) { Set.new }
      @controller.helpers.define_singleton_method(:can_access_app?) { |*| true }
      @gsa = Aim::AgencyGroup.for_agency!('GSA')
      @gsa.roles.create!(employee_id: 42, role: 'fiscal')
      @sheriff = Aim::AgencyGroup.for_agency!('SHF')
    end

    def areas(*rows_per_area) = rows_per_area.map { |rows| { 'name' => 'Area', 'rows' => rows } }.to_json

    test 'a group starts from the default, the built-in stamp or another group, saving nothing until Save (#229)' do
      Aim::StampLayout.create!(created_by: 'admin@example.com', area_list: [{ 'rows' => ['DEFAULT {approver}'] }])
      theirs = Aim::StampLayout.create!(agency_group: @sheriff, created_by: 'x', area_list: [{ 'rows' => ['SHERIFF {approver}'] }])

      get :edit, params: { id: @gsa.id }
      assert_select '.aim-page-subtitle', text: /has no layout of its own yet/
      assert_select '[data-stamp-designer-areas-value*=?]', 'DEFAULT {approver}'
      assert_select 'select[name=start_from] option', text: "#{@sheriff.name}'s layout"

      get :edit, params: { id: @gsa.id, start_from: @sheriff.id }
      assert_select '[data-stamp-designer-areas-value*=?]', 'SHERIFF {approver}'
      assert_select '.aim-page-subtitle', text: /Loaded from #{Regexp.escape(@sheriff.name)}'s layout; not saved yet/

      get :edit, params: { id: @gsa.id, start_from: 'built_in' }
      assert_select '[data-stamp-designer-areas-value*=?]', '{approver}_{approved_at}'
      assert_equal 2, Aim::StampLayout.count, 'loading saves nothing'

      patch :update, params: { id: @gsa.id, areas: areas(['SHERIFF {approver} for GSA']), restamp: 'new' }
      assert_equal ['SHERIFF {approver} for GSA'], Aim::StampLayout.current_for(@gsa).area_list.first['rows']
      assert_equal ['SHERIFF {approver}'], theirs.reload.area_list.first['rows'], 'the source is untouched'
    end

    test 'a group with no layout of its own is not offered to start from' do
      get :edit, params: { id: @gsa.id }

      assert_select 'select[name=start_from] option', text: "#{@sheriff.name}'s layout", count: 0
      get :edit, params: { id: @gsa.id, start_from: @sheriff.id }
      assert_select '.aim-page-subtitle', text: /Loaded from/, count: 0
    end
  end
end
