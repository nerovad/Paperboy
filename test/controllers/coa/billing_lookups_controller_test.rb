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
    assert_select '.coa-billing-field select', count: 10
    assert_select '.coa-billing-result[data-coa-billing-lookup-target=?][hidden]', 'result', count: 1
    assert_select '.coa-lookup-card[data-coa-billing-lookup-target=?][hidden]', 'accountFields', count: 1
    assert_select '.coa-account-tree [data-coa-billing-lookup-target]', count: 8
    assert_select '.coa-lookup-card__heading', count: 4
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

  test 'CFUNCTION combines county funds with agency functions' do
    funds = option_relation([['General Fund', '001']])
    functions = option_relation([['General Services Function', 'GFUN']])
    finder = lambda do |conditions|
      assert_equal({ agency_id: 'GSA' }, conditions)
      functions
    end

    Coa::Fund.stub(:all, funds) do
      Coa::Function.stub(:where, finder) do
        get :cfunctions, params: { agency_id: 'GSA' }
      end
    end

    assert_response :success
    assert_equal [
      { 'label' => '001 - General Fund (Fund)', 'value' => '001' },
      { 'label' => 'GFUN - General Services Function (Function)', 'value' => 'GFUN' }
    ], response.parsed_body
  end

  private

  def option_relation(rows)
    relation = Object.new
    relation.define_singleton_method(:order) { |_column| self }
    relation.define_singleton_method(:pluck) { |_label, _value| rows }
    relation
  end
end
