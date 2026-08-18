# frozen_string_literal: true

require 'test_helper'

class DslGroupRefreshControllerTest < ActionController::TestCase
  tests DataRunner::GroupRefreshesController

  test 'group editor colors enabled DSL buttons only' do
    sign_in

    get :index, params: { group: 'paperboy' }

    assert_response :success
    assert_select '.dsl-pill.btn.approve[data-dsl-enabled=?]', 'true', minimum: 1
    assert_select '.dsl-pill.approve[data-dsl-slug=?]', 'parking_lots', false
    assert_select '.dsl-pill.btn:not(.approve)[data-dsl-slug=?][data-dsl-enabled=?]', 'parking_lots', 'false'
  end

  test 'refresh group run selection excludes disabled DSLs' do
    sign_in
    run = Struct.new(:id) do
      def to_param = id.to_s
    end.new(42)

    with_group_refresh_stub(run) do |calls|
      post :create, params: { group: 'paperboy' }

      assert_redirected_to data_runner_group_run_path(run)
      assert_equal 'paperboy', calls.first.fetch(:group)
      assert_includes calls.first.fetch(:entries).map(&:slug), 'building_data'
      assert_not_includes calls.first.fetch(:entries).map(&:slug), 'parking_lots'
      assert_equal 'employee@example.com', calls.first.fetch(:requested_by)
    end
  end

  test 'restart replaces an interrupted group run' do
    sign_in
    run = Struct.new(:id) do
      def to_param = id.to_s
    end.new(43)
    original = DataRunner::GroupRefresh.method(:restart!)
    calls = []
    DataRunner::GroupRefresh.define_singleton_method(:restart!) do |**arguments|
      calls << arguments
      run
    end

    post :create, params: { group: 'paperboy', restart: '1' }

    assert_redirected_to data_runner_group_run_path(run)
    assert_equal 'paperboy', calls.first.fetch(:group)
    assert_match(/Paperboy refresh restarted for \d+ DSLs\./, flash[:notice])
  ensure
    DataRunner::GroupRefresh.define_singleton_method(:restart!, original) if original
  end

  private

  def sign_in
    session[:user] = {
      'employee_id' => 1,
      'email' => 'employee@example.com',
      'first_name' => 'Test',
      'last_name' => 'User'
    }
  end

  def with_group_refresh_stub(run)
    original = DataRunner::GroupRefresh.method(:start!)
    calls = []
    DataRunner::GroupRefresh.define_singleton_method(:start!) do |**arguments|
      calls << arguments
      run
    end

    yield calls
  ensure
    DataRunner::GroupRefresh.define_singleton_method(:start!, original)
  end
end
