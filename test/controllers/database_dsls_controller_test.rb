# frozen_string_literal: true

require 'test_helper'

class DatabaseDslsControllerTest < ActionController::TestCase
  tests DataRunner::DatabaseDslsController

  setup { sign_in }

  test 'the import form locks both servers and offers the target schema list' do
    with_replication_env do
      get :new

      assert_response :success
      assert_select 'input[name="server"][readonly="readonly"][value=?]', '10.1.1.16'
      assert_select 'input[name="target_server"][readonly="readonly"][value=?]', 'gsa-sql22-tst.example'
      assert_select 'input[name="replicate"][value=?]', '1'
      assert_select 'select[name="target_schema"]'
      assert_select 'select[name="target_table"]'
      assert_select '[data-database-dsl-selected-target-database-value=?]', 'Paperboy'
      assert_select 'section[data-database-dsl-target="targetCard"]:not([hidden])'
    end
  end

  test 'schema choices come from the target catalog' do
    catalog = Object.new
    catalog.define_singleton_method(:schemas) { |_server, _database| %w[bss dbo] }
    with_replication_env do
      DataRunnerDatabaseCatalog.stub(:new, catalog) do
        get :schemas, params: { server: 'gsa-sql22-tst.example', database: 'Paperboy' }
      end

      assert_response :success
      assert_equal %w[bss dbo], JSON.parse(response.body)
    end
  end

  private

  def sign_in
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
  end

  def with_replication_env
    previous = %w[GSABSS_HOST MSSQL_HOST SQL22 SQL22_HOST SQL22_DB].to_h { |key| [key, ENV.fetch(key, nil)] }
    ENV['GSABSS_HOST'] = '10.1.1.16'
    ENV['MSSQL_HOST'] = 'other-host'
    ENV['SQL22'] = '10.1.1.22'
    ENV['SQL22_HOST'] = 'gsa-sql22-tst.example'
    ENV['SQL22_DB'] = 'Paperboy'
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
