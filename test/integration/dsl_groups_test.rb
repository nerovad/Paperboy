# frozen_string_literal: true

require "test_helper"

class DslGroupsTest < ActionDispatch::IntegrationTest
  test "group update requires login" do
    patch data_runner_dsl_group_path("chart_of_accounts"), params: { dsl_slugs: [ "employees" ] }

    assert_redirected_to data_runner_root_path
  end
end
