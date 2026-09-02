# frozen_string_literal: true

require 'test_helper'

class CoaCustomerLookupsControllerTest < ActionController::TestCase
  tests Coa::CustomerLookupsController

  setup do
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com' }
    @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    @controller.define_singleton_method(:inbox_count) { 0 }
  end

  test 'show renders employee selection and sidebar link below billing lookup' do
    get :show

    assert_response :success
    assert_select 'h1', text: 'Employee Lookup'
    assert_select '#employee-selection-title', text: 'Employee Selection'
    assert_select 'input[placeholder=?]', 'Search first name, last name, or employee ID…'
    assert_select '[data-controller=?]', 'coa-account-hierarchy', count: 1
    assert_select '.coa-sidebar .coa-table-links a:nth-of-type(1)', text: 'Billing Lookup'
    assert_select '.coa-sidebar .coa-table-links a:nth-of-type(2)', text: 'Employee Lookup'
  end

  test 'employees fuzzy finds first or last name and limits results' do
    matches = employee_relation([[7, 'Avery', 'Smith', '1450']])
    finder = lambda do |clause, query:|
      assert_equal 'first_name LIKE :query OR last_name LIKE :query', clause
      assert_equal '%mit%', query
      matches
    end

    Employee.stub(:where, finder) do
      get :employees, params: { q: 'mit' }
    end

    assert_response :success
    assert_equal [{ 'value' => 7, 'label' => 'Smith, Avery (7)', 'unit' => '1450' }],
                 response.parsed_body
    assert_equal 20, matches.limit_value
  end

  test 'blank employee search does not query GSABSS' do
    Employee.stub(:where, ->(*) { flunk 'blank search queried employees' }) do
      get :employees, params: { q: ' ' }
    end

    assert_response :success
    assert_equal [], response.parsed_body
  end

  test 'hierarchy resolves a standard employee unit into four nodes' do
    employee = record(id: 7, first_name: 'Avery', last_name: 'Smith', agency: 'GSA', unit: '1450',
                      email: 'avery.smith@example.com', work_phone: '805-555-0100')
    unit = record(agency_id: 'GSA', division_id: 'GSA1', department_id: '1400',
                  unit_id: '1450', long_name: 'Business Support')

    stub_hierarchy(employee, unit: unit) do
      get :hierarchy, params: { employee_id: 7 }
    end

    assert_response :success
    assert_equal %w[Agency Division Department Unit], response.parsed_body['nodes'].pluck('level')
    assert_equal %w[GSA GSA1 1400 1450], response.parsed_body['nodes'].pluck('id')
    assert_equal({ 'email' => 'avery.smith@example.com', 'phone' => '805-555-0100' }, response.parsed_body['contact'])
  end

  test 'HCA hierarchy matches employee unit to a fifth sub-unit node' do
    employee = record(id: 8, first_name: 'Jordan', last_name: 'Lee', agency: 'HCAV', unit: '4321',
                      email: nil, work_phone: nil)
    sub_unit = record(agency_id: 'HCA', unit_id: '1200', sub_unit_id: '4321',
                      sub_unit_name: 'Clinical Services')
    unit = record(agency_id: 'HCA', division_id: 'HCA1', department_id: '1100',
                  unit_id: '1200', long_name: 'Health Services')

    stub_hierarchy(employee, unit: unit, sub_unit: sub_unit, normalized_agency: 'HCA') do
      get :hierarchy, params: { employee_id: 8 }
    end

    assert_response :success
    assert_equal %w[Agency Division Department Unit Sub-Unit], response.parsed_body['nodes'].pluck('level')
    assert_equal '4321', response.parsed_body['nodes'].last['id']
  end

  private

  def employee_relation(rows)
    relation = Object.new
    relation.define_singleton_method(:order) { |*| self }
    relation.define_singleton_method(:limit) do |value|
      @limit_value = value
      self
    end
    relation.define_singleton_method(:limit_value) { @limit_value }
    relation.define_singleton_method(:pluck) { |*| rows }
    relation
  end

  def record(attributes)
    Struct.new(*attributes.keys, keyword_init: true).new(**attributes)
  end

  def stub_hierarchy(employee, unit:, sub_unit: nil, normalized_agency: employee.agency, &block)
    employee_scope = Object.new
    employee_scope.define_singleton_method(:find) { |_id| employee }

    agency = record(long_name: 'Agency Name')
    division = record(long_name: 'Division Name')
    department = record(long_name: 'Department Name')

    Employee.stub(:select, employee_scope) do
      Coa::Agency.stub(:normalize_id, normalized_agency) do
        Coa::SubUnit.stub(:find_by, sub_unit) do
          Coa::Unit.stub(:find_by, unit) do
            Coa::Agency.stub(:find_by, agency) do
              Coa::Division.stub(:find_by, division) do
                Coa::Department.stub(:find_by, department, &block)
              end
            end
          end
        end
      end
    end
  end
end

class CoaAccountItemLookupsControllerTest < ActionController::TestCase
  tests Coa::CustomerLookupsController

  setup do
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com' }
    @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    @controller.define_singleton_method(:inbox_count) { 0 }
  end

  test 'show renders the Chart of Account item lookup card' do
    get :show

    assert_response :success
    assert_select '#account-item-lookup-title', text: 'Chart of Account Item Lookup'
    assert_select '[data-coa-customer-lookup-target=accountItemCard][hidden]', count: 1
    assert_select 'label[for=account_item_search]', text: 'Find'
    assert_select '[data-coa-customer-lookup-account-items-url-value=?]',
                  account_items_coa_customer_lookup_path
  end

  test 'reports every table containing the exact id' do
    requested = []
    matches = { Coa::Activity => true, Coa::Program => true }

    with_account_item_stubs(requested, matches) do
      get :account_items, params: { q: ' 100 ' }
    end

    assert_response :success
    assert_equal %w[Activity Program], response.parsed_body['tables']
    assert_equal expected_requests('100'), requested
  end

  test 'blank query does not search account tables' do
    Coa::Activity.stub(:exists?, ->(*) { flunk 'blank lookup queried an account table' }) do
      get :account_items, params: { q: ' ' }
    end

    assert_response :success
    assert_equal({ 'tables' => [] }, response.parsed_body)
  end

  private

  def with_account_item_stubs(requested, matches, index = 0, &block)
    table = Coa::CustomerLookupsController::ACCOUNT_ITEM_TABLES[index]
    return yield unless table

    model_class, = table
    finder = lambda do |conditions|
      requested << [model_class, conditions]
      matches.fetch(model_class, false)
    end
    model_class.stub(:exists?, finder) do
      with_account_item_stubs(requested, matches, index + 1, &block)
    end
  end

  def expected_requests(query)
    Coa::CustomerLookupsController::ACCOUNT_ITEM_TABLES.map do |model_class, column, _label|
      [model_class, { column => query }]
    end
  end
end

class CoaEmployeeIdLookupsControllerTest < ActionController::TestCase
  tests Coa::CustomerLookupsController

  setup do
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com' }
    @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    @controller.define_singleton_method(:inbox_count) { 0 }
  end

  test 'employees finds numeric input by employee id' do
    matches = employee_relation([[102_989, 'Avery', 'Smith', '1450']])
    finder = lambda do |conditions|
      assert_equal({ id: '102989' }, conditions)
      matches
    end

    Employee.stub(:where, finder) { get :employees, params: { q: '102989' } }

    assert_response :success
    assert_equal [{ 'value' => 102_989, 'label' => 'Smith, Avery (102989)', 'unit' => '1450' }],
                 response.parsed_body
    assert_equal 20, matches.limit_value
  end

  private

  def employee_relation(rows)
    relation = Object.new
    relation.define_singleton_method(:order) { |*| self }
    relation.define_singleton_method(:limit) do |value|
      @limit_value = value
      self
    end
    relation.define_singleton_method(:limit_value) { @limit_value }
    relation.define_singleton_method(:pluck) { |*| rows }
    relation
  end
end
