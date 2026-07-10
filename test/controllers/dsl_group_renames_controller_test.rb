# frozen_string_literal: true

require "test_helper"

class DslGroupRenamesControllerTest < ActionController::TestCase
  tests DataRunner::DslsController

  test "rename group rejects existing DSL names with alert" do
    sign_in

    patch :rename_group, params: { group: "chart_of_accounts", new_group_name: "Employees" }

    assert_redirected_to data_runner_root_path(group: "chart_of_accounts")
    assert_equal "Cannot rename DSL Group Chart of accounts to DSL Name Employees", flash[:alert]
    assert_nil flash[:notice]
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
end
