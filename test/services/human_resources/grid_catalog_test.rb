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

      assert_equal ['Employees', 'Bargaining Units', 'FLSA Status', 'Job Salaries', 'Unions', 'Union codes',
                    'VCHRP unions'], sidebar.map(&:label)
      assert_equal TABLES.keys, sidebar.map(&:slug)

      TABLES.each do |slug, table|
        definition = GridCatalog.find!(slug)

        assert_equal table, definition.table
        assert_equal 'dbo', definition.schema
        assert_equal 'GSABSS', definition.database
        assert definition.columns.any?
      end
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
