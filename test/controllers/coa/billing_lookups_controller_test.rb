# frozen_string_literal: true

require 'test_helper'

class CoaBillingLookupsControllerTest < ActionController::TestCase
  tests Coa::BillingLookupsController

  setup do
    session[:user] = {
      'employee_id' => 1,
      'email' => 'employee@example.com',
      'first_name' => 'Test',
      'last_name' => 'User'
    }
    @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    @controller.define_singleton_method(:inbox_count) { 0 }
  end

  test 'show renders long agency names and Billing Lookup sidebar link' do
    relation = option_relation([['General Services Agency', 'GSA']])

    Coa::Agency.stub(:all, relation) do
      get :show
    end

    assert_response :success
    assert_select '#billing_agency option[value=?]', 'GSA', text: 'GSA - General Services Agency'
    assert_select '[data-controller=?]', 'coa-billing-lookup'
    assert_select '.coa-billing-field select, .coa-billing-string-grid__field select', count: 10
    assert_select '.coa-billing-result[data-controller=?][hidden]', 'coa-billing-string', count: 1
    assert_select '.coa-lookup-card[data-controller=?][hidden]', 'coa-account-hierarchy', count: 1
    assert_select '[data-coa-account-hierarchy-target]', count: 3
    assert_select '.coa-lookup-card__heading', count: 3
    assert_select '#tc60-fields-title', count: 0
    assert_select '.coa-billing-string-grid .coa-billing-string-grid__field select', count: 6
    assert_select '#billing-account-string-title + .coa-lookup-card__body .coa-billing-string-grid', count: 1
    assert_select '.coa-billing-string-grid__heading', count: 10
    assert_select '.coa-sidebar a[href=?]', coa_billing_lookup_path, text: 'Billing Lookup'
    assert_select '.coa-sidebar a', text: 'Overview', count: 0
  end

  test 'units are restricted by the complete organization hierarchy' do
    relation = option_relation([['Business Support Services', '1450']])
    expected = { agency_id: 'GSA', division_id: 'GSA1', department_id: '1400' }
    finder = lambda do |conditions|
      assert_equal expected, conditions
      relation
    end

    Coa::Unit.stub(:where, finder) do
      get :units, params: expected
    end

    assert_response :success
    assert_equal [{ 'label' => '1450 - Business Support Services', 'value' => '1450' }], response.parsed_body
  end

  test 'CFUNCTION only includes functions for the selected agency' do
    functions = option_relation([['General Services Function', 'GFUN']])
    finder = lambda do |conditions|
      assert_equal({ agency_id: 'GSA' }, conditions)
      functions
    end

    Coa::Function.stub(:where, finder) do
      get :cfunctions, params: { agency_id: 'GSA' }
    end

    assert_response :success
    assert_equal [
      { 'label' => 'GFUN - General Services Function', 'value' => 'GFUN' }
    ], response.parsed_body
  end

  test 'COBJECT includes county-wide objects' do
    objects = option_relation([['Professional Services', 2100]])

    Coa::Object.stub(:all, objects) do
      get :objects
    end

    assert_response :success
    assert_equal [
      { 'label' => '2100 - Professional Services', 'value' => 2100 }
    ], response.parsed_body
  end

  test 'agency-backed accounting fields are restricted to the selected agency' do
    fields = [
      [Coa::Activity, :activities, 'Information Technology', 'IT'],
      [Coa::Program, :programs, 'Information Technology Services', 'ITS'],
      [Coa::Phase, :phases, 'Implementation Phase', 'IMP'],
      [Coa::Task, :tasks, 'Application Support', 'APP']
    ]

    fields.each do |model, action, name, value|
      finder = lambda do |conditions|
        assert_equal({ agency_id: 'GSA' }, conditions)
        option_relation([[name, value]])
      end

      model.stub(:where, finder) do
        get action, params: { agency_id: 'GSA' }
      end

      assert_response :success
      assert_equal [{ 'label' => "#{value} - #{name}", 'value' => value }], response.parsed_body
    end
  end

  private

  def option_relation(rows)
    relation = Object.new
    relation.define_singleton_method(:order) { |_column| self }
    relation.define_singleton_method(:pluck) { |_label, _value| rows }
    relation
  end
end
