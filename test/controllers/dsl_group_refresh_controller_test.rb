# frozen_string_literal: true

require "test_helper"

class DslGroupRefreshControllerTest < ActionController::TestCase
  tests DataRunner::DslsController

  test "group editor colors enabled DSL pills only" do
    sign_in

    get :index, params: { group: "paperboy" }

    assert_response :success
    assert_select ".dsl-pill.enabled[data-dsl-enabled=?]", "true", minimum: 1
    assert_select ".dsl-pill.enabled[data-dsl-slug=?]", "parking_lots", false
    assert_select ".dsl-pill[data-dsl-slug=?][data-dsl-enabled=?]", "parking_lots", "false"
  end

  test "refresh group run selection excludes disabled DSLs" do
    sign_in
    result = TaskRunner::Result.new(id: "00000000-0000-0000-0000-000000000000", success: true)

    with_task_runner_stub(result) do |calls|
      post :refresh_group, params: { group: "paperboy" }

      assert_redirected_to data_runner_run_path(result.id)
      assert_equal "refresh", calls.first.first
      assert_includes calls.first.second, "building_data"
      assert_not_includes calls.first.second, "parking_lots"
    end
  end

  private

  def sign_in
    session[:user] = {
      "employee_id" => 1,
      "email" => "employee@example.com",
      "first_name" => "Test",
      "last_name" => "User"
    }
  end

  def with_task_runner_stub(result)
    original = TaskRunner.method(:run!)
    calls = []
    TaskRunner.define_singleton_method(:run!) do |task:, selector:|
      calls << [ task, selector ]
      result
    end

    yield calls
  ensure
    TaskRunner.define_singleton_method(:run!, original)
  end
end
