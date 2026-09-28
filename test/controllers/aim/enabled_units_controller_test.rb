# frozen_string_literal: true

require 'test_helper'

module Aim
  # Admin -> AIM's budget units (2026-09-28): the BUs every AIM list offers.
  class EnabledUnitsControllerTest < ActionController::TestCase
    tests Aim::EnabledUnitsController

    setup do
      session[:user] = { 'email' => 'aim.admin@example.com', 'employee_id' => 42 }
      as_groups 'aim_admin'
      @gsa = Coa::Unit.where(agency_id: 'GSA', active: true).order(:unit_id).limit(2).pluck(:unit_id)
      skip 'need two active GSA units in the COA' if @gsa.size < 2
    end

    test 'lists every agency with Entire agency and a box per unit, GSA ticked before the first save' do
      get :index

      assert_response :success
      assert_select 'input[type=checkbox][name="agencies[]"][value=GSA][checked]'
      assert_select "input[type=checkbox][name='units[]'][value='#{@gsa.first}']"
    end

    test 'single units limit every list to them; a whole agency takes all its units' do
      patch :update, params: { units: [@gsa.first] }

      assert_equal [@gsa.first], Aim::Units.new.all.map(&:unit)
      assert Aim::Units.new.valid?(@gsa.first)
      assert_not Aim::Units.new.valid?(@gsa.last)

      patch :update, params: { agencies: ['GSA'], units: [@gsa.first] }
      assert_equal [['GSA', nil]], Aim::EnabledUnit.pluck(:agency_id, :unit_id), 'the agency, not its units one by one'
      assert Aim::Units.new.valid?(@gsa.last)
    end

    test 'units that are not in the COA are ignored' do
      patch :update, params: { units: [@gsa.first, 'ZZZZ'], agencies: ['NOPE'] }

      assert_equal [['GSA', @gsa.first]], Aim::EnabledUnit.pluck(:agency_id, :unit_id)
    end

    test 'only AIM Admins' do
      as_groups

      get :index

      assert_redirected_to aim_root_path
    end

    private

    def as_groups(*names)
      @controller.define_singleton_method(:current_user_group_names) { Set.new(names) }
    end
  end
end
