# frozen_string_literal: true

require "test_helper"

class DslEditActionsControllerTest < ActionController::TestCase
  tests DataRunner::DslsController

  test "edit action bar places save between edit and delete" do
    sign_in

    get :edit, params: { name: "employees" }

    assert_response :success
    assert_select ".hot-menu input.button.primary[value=?][form=?]", "Save", "dsl-source-form"
    assert_select ".hot-menu a.button[href=?]", data_runner_dsl_path("employees"), text: "Cancel"
    assert_select ".hot-menu form[action=?] .button.danger", data_runner_dsl_path("employees"), false
    assert_select ".hot-menu .button", text: "Outputs", count: 0
    assert_select ".hot-menu summary.button.primary", text: "Run Task", count: 0
    assert_select ".form-actions input[value=?]", "Save DSL", false
    assert_edit_action_order
  end

  private

  def assert_edit_action_order
    cursor = -1
    [ ">Edit<", 'value="Save"', ">Cancel<" ].each do |text|
      cursor = response.body.index(text, cursor + 1)
      assert cursor, "Expected #{text.inspect} after prior edit action"
    end
  end

  def sign_in
    session[:user] = {
      "employee_id" => 1,
      "email" => "employee@example.com",
      "first_name" => "Test",
      "last_name" => "User"
    }
  end
end
