# frozen_string_literal: true

require "test_helper"

class DslsControllerTest < ActionController::TestCase
  tests DataRunner::DslsController

  test "control center starts with an empty palette" do
    sign_in

    get :index

    assert_response :success
    assert_select "h2", text: "Empty palette"
  end

  test "group selection opens the control center group editor" do
    sign_in

    get :index, params: { group: "chart_of_accounts" }

    assert_response :success
    assert_select "form[action=?]", data_runner_dsl_group_path("chart_of_accounts")
    assert_select ".dsl-pill", minimum: 1
    assert_select ".dsl-pill a", false
    assert_select ".nav-link[onmousedown*=?]", "DataRunnerStartDslDrag", minimum: 1
    assert_select ".control-center-actions input[value=?]", "Save DSLs"
    assert_select ".control-center-actions label[for=?]", "new_group_name", false
    assert_select ".control-center-actions input[name=?][placeholder=?]", "new_group_name", "Rename dslGroup name"
    assert_select ".control-center-actions input[value=?]", "Update", false
    assert_select ".control-center-actions button[data-dsl-group-target=?][disabled=?]", "renameButton", "disabled", text: "Update"
    assert_select ".control-center-actions .button.danger", text: "Delete"
    assert_select ".control-center-actions .button.success", text: "Refresh"
    assert_select "form[action=?]", data_runner_rename_dsl_group_path("chart_of_accounts")
    assert_select "form[action=?]", data_runner_destroy_dsl_group_path("chart_of_accounts")
    assert_select "form[action=?]", data_runner_refresh_dsl_group_path("chart_of_accounts")
  end

  test "dsl action bar contains ordered edit delete and output actions" do
    sign_in

    get :show, params: { name: "employees" }

    assert_response :success
    assert_dsl_layout_order
    assert_select ".page-heading form[action=?]", data_runner_dsl_path("employees"), false
    assert_select ".hot-menu .button", text: "Overview"
    assert_select ".hot-menu .button.success", text: "Edit"
    assert_select ".hot-menu form[action=?] .button.danger", data_runner_dsl_path("employees"), text: "Delete"
    assert_select ".hot-menu .button", text: "Outputs"
    assert_select ".hot-menu summary.button.primary", text: "Run Task"
  end

  test "edit form uses syntax highlighted source editor" do
    sign_in

    get :edit, params: { name: "employees" }

    assert_response :success
    assert_select "[data-controller=?]", "source-editor"
    assert_select "pre.code-editor-highlight .k", minimum: 1
    assert_select "textarea[name=?][data-source-editor-target=?]", "source", "input"
  end

  test "new group form is available from account menu" do
    sign_in

    get :new_group

    assert_response :success
    assert_select "form[action=?]", data_runner_dsl_groups_path
    assert_select "input[name=?]", "group_name"
  end

  test "create group normalizes name and opens an empty group palette" do
    sign_in

    post :create_group, params: { group_name: "Finance Reporting" }

    assert_redirected_to data_runner_root_path(group: "finance_reporting")
  end

  test "csv output uses datatables with per-column filters" do
    sign_in
    output_path = Rails.root.join("05_DSL_Applied", "employees.csv")
    output_path.dirname.mkpath
    output_path.write("id,name\n1,Ada\n2,Grace\n")

    get :output, params: { name: "employees", path: "05_DSL_Applied/employees.csv" }

    assert_response :success
    assert_select "script[src*=?]", "jquery3"
    assert_select "script[src*=?]", "datatables/jquery.dataTables"
    assert_select "script[src*=?]", "datatables/extensions/Buttons/dataTables.buttons"
    assert_select "script[src*=?]", "datatables/extensions/Responsive/dataTables.responsive"
    assert_select "table.datatable-output[data-controller=?]", "output-table"
    assert_select "thead tr.column-filters input", count: 2
  ensure
    output_path&.delete if output_path&.file?
  end

  test "sql output is syntax highlighted with rouge" do
    sign_in
    output_path = Rails.root.join("04_SQL_SCHEMA", "employees.sql")
    output_path.dirname.mkpath
    output_path.write("SELECT id FROM employees WHERE id = 1;\n")

    get :output, params: { name: "employees", path: "04_SQL_SCHEMA/employees.sql" }

    assert_response :success
    assert_select "pre.highlighted-output"
    assert_select "pre.highlighted-output .k", text: "SELECT"
  ensure
    output_path&.delete if output_path&.file?
  end

  private

  def assert_dsl_layout_order
    cursor = -1
    [ '<div class="dsl-header">', 'class="eyebrow"', "Employees", "Source", "Destination", "Workflow",
     'aria-label="DSL actions"' ].each do |text|
      cursor = response.body.index(text, cursor + 1)
      assert cursor, "Expected #{text.inspect} after prior DSL layout content"
    end
  end

  def sign_in
    session[:user] = { "employee_id" => 1, "email" => "employee@example.com", "first_name" => "Test", "last_name" => "User" }
  end
end
