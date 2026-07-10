# frozen_string_literal: true

require "test_helper"

class TaskRunnerTest < ActiveSupport::TestCase
  test "rejects arbitrary task names before execution" do
    error = assert_raises(ArgumentError) { TaskRunner.run!(task: "db:drop", selector: "employees") }

    assert_equal "Task is not allowed", error.message
  end

  test "rejects invalid run ids" do
    assert_raises(ActiveRecord::RecordNotFound) { TaskRunner.output!("../../etc/passwd") }
  end

  test "resolves dsl slugs and group names for rake selectors" do
    assert_equal "Employees", TaskRunner.selector_name!("employees")
    assert_equal "chart_of_accounts", TaskRunner.selector_name!("chart_of_accounts")
    assert_raises(ActiveRecord::RecordNotFound) { TaskRunner.selector_name!("missing_selector") }
  end

  test "resolves multiple dsl selectors" do
    assert_equal %w[Employees ParkingLots], TaskRunner.selector_names!(%w[employees parking_lots])
  end
end
