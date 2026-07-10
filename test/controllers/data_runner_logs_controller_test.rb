# frozen_string_literal: true

require "test_helper"

class DataRunnerLogsControllerTest < ActionController::TestCase
  tests DataRunner::LogsController

  setup do
    sign_in
    ActiveRecord::Base.connection.create_table(:datarunner_log, force: true) do |table|
      table.string :run_id
      table.string :command
      table.string :script
      table.text :arguments
      table.string :selector
      table.string :status
      table.integer :exit_status
      table.datetime :started_at
      table.datetime :completed_at
      table.integer :duration_ms
    end
  end

  test "index renders run log command bar in menu order" do
    get :index

    assert_response :success
    assert_select ".run-log-menu .button", text: "Run Logs"
    assert_select ".run-log-menu label", text: "Date"
    assert_select ".run-log-menu label", text: "Command"
    assert_select ".run-log-menu label", text: "DSL"
    assert_select ".run-log-menu label", text: "Status"
    assert_select ".run-log-menu label", text: "Duration"
    assert_select ".run-log-menu .button.primary", text: "New Log"
  end

  test "show confirms log deletion" do
    log = create_log

    get :show, params: { id: log.id }

    assert_response :success
    assert_select "form[action=?] button[data-turbo-confirm=?]",
                  data_runner_log_path(log), "Delete this log entry? This cannot be undone."
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

  def create_log
    now = Time.zone.local(2026, 6, 22, 10)
    DataRunner::Log.create!(
      run_id: SecureRandom.uuid,
      command: "refresh",
      script: "download.rb",
      selector: "employees",
      status: "succeeded",
      started_at: now,
      completed_at: now,
      duration_ms: 100
    )
  end
end
