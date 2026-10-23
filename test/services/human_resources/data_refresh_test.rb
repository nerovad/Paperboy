# frozen_string_literal: true

require 'test_helper'

module HumanResources
  class DataRefreshTest < ActiveSupport::TestCase
    test 'refreshes the Data Runner human_resources group when it is selected' do
      result = DataRunner::GroupRun.new(group_name: DataRefresh::GROUP_RUN_NAME, total_count: 1)
      calls = []
      runner = lambda do |**arguments|
        calls << arguments
        result
      end
      enabled = Struct.new(:slug, :key) do
        def enabled? = true
      end
      catalog = { 'human_resources' => [enabled.new('employees', 'Employees')] }

      DslCatalog.stub(:grouped, catalog) do
        DataRunner::GroupRefresh.stub(:start!, runner) do
          DataRefresh.run!({ 'human_resources' => '1' }, requested_by: 'hr@example.com')
        end
      end

      assert_equal DataRefresh::GROUP_RUN_NAME, calls.first.fetch(:group)
      assert_equal ['employees'], calls.first.fetch(:entries).map(&:slug)
      assert_equal 'hr@example.com', calls.first.fetch(:requested_by)
    end

    test 'selects the human_resources group by default' do
      assert_equal true, DataRefresh::GROUPS.fetch('human_resources').fetch(:default)
      assert_equal ['human_resources'], DataRefresh::GROUPS.keys
    end
  end
end
