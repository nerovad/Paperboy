# frozen_string_literal: true

require 'test_helper'

module HumanResources
  class GridCatalogTest < ActiveSupport::TestCase
    TABLES = {
      'employees' => 'employees',
      'bargaining_units' => 'bargaining_units',
      'flsa_statuses' => 'flsa_statuses',
      'job_salaries' => 'job_salaries',
      'unions' => 'unions',
      'union_codes' => 'union_codes',
      'vchrp_unions' => 'vchrp_unions'
    }.freeze

    test 'sidebar grids take their tables and columns from the human resources dsls' do
      sidebar = GridCatalog.sidebar

      assert_equal ['Employees', 'GSA Employee', 'Bargaining Units', 'FLSA Status', 'Job Salaries', 'Unions',
                    'Union codes', 'VCHRP unions'], sidebar.map(&:label)
      assert_equal ['employees', 'gsa_employees', *TABLES.keys.drop(1)], sidebar.map(&:slug)

      TABLES.each do |slug, table|
        definition = GridCatalog.find!(slug)

        assert_equal table, definition.table
        assert_equal 'dbo', definition.schema
        assert_equal 'GSABSS', definition.database
        assert definition.columns.any?
      end
    end

    SEARCH = {
      'employees' => %w[id last_name first_name],
      'bargaining_units' => %w[bargaining_unit_id description],
      'flsa_statuses' => %w[flsa_stat_id description legend_rate_basis],
      'job_salaries' => %w[job_code_id job_title],
      'unions' => %w[union_id description],
      'union_codes' => %w[union_id barg_unit vchrp_union description],
      'vchrp_unions' => %w[vchrp_union_id description]
    }.freeze

    test 'each grid searches only its named columns' do
      SEARCH.each do |slug, columns|
        definition = GridCatalog.find!(slug)

        assert_equal columns, definition.search_columns
        assert_empty definition.search_columns - definition.columns
      end
    end

    test 'gsa employees shows the joined columns and searches the named fields' do
      gsa = GridCatalog.find!('gsa_employees')

      assert_equal %w[agency_id division_id department_id unit_id employee_id first_name last_name job_code
                      job_title at_will vchrp_code flsa_stat rate_basis rate_min rate_max], gsa.columns
      assert_equal %w[agency_id division_id department_id unit_id job_code_id job_title employee_id
                      first_name last_name], gsa.search_columns
      assert_equal 'GSABSS', gsa.database
    end

    test 'employees keeps the source columns and omits the destination-only active flag' do
      employees = GridCatalog.find!('employees')

      assert_equal %w[id last_name first_name job_title work_phone agency unit job_code position pay_status
                      job_class department type supervisor_id supervisor_last_name supervisor_first_name
                      person_email email], employees.columns
    end

    test 'an unknown sidebar name is refused' do
      assert_raises(ActiveRecord::RecordNotFound) { GridCatalog.find!('fiscalmonths') }
    end
  end
end
