# frozen_string_literal: true

require 'test_helper'

class P2mDataRefreshesControllerTest < ActionController::TestCase
  tests P2m::DataRefreshesController

  test 'shows queued OMS numbers in a stripped refresh grid' do
    sign_in

    with_oms_catalog do
      get :show
    end

    assert_response :success
    assert_select 'table.p2m-data-refresh-table' do
      assert_select 'th', text: 'OMS Number'
      assert_select 'th', text: 'Data Runner DSL'
      assert_select 'th', text: 'Refresh'
      assert_select 'td', text: '51671902'
      assert_select 'td', text: '51786524'
      assert_select 'td', text: 'OMS 51671902', count: 0
    end
    assert_select 'input[type=hidden][name=?][value=?]', 'groups[print_2_mail_billing_data]', '1'
    assert_select 'input[type=submit][value=?]', 'Refresh'
    assert_select 'button', text: 'Reset', count: 0
  end

  test 'queue outage redirects back to the refresh form' do
    sign_in
    original = P2m::DataRefresh.method(:run!)
    P2m::DataRefresh.define_singleton_method(:run!) do |*, **|
      raise DataRunner::GroupRefresh::QueueUnavailable, 'connection refused'
    end

    patch :update, params: { groups: { print_2_mail_billing_data: '1' } }

    assert_redirected_to p2m_data_refresh_path
    assert_equal 'The data refresh could not be queued because Redis is unavailable.', flash[:alert]
  ensure
    P2m::DataRefresh.define_singleton_method(:run!, original) if original
  end

  private

  def sign_in
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
    @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
  end

  def with_oms_catalog(&block)
    Dir.mktmpdir do |directory|
      queue = Pathname.new(directory).join('sent').tap(&:mkpath)
      queue.join('Mail.dat_51786524.zip').write('marker')
      queue.join('Mail.dat_51671902.zip').write('marker')
      entry = Struct.new(:slug, :key, :config, :sop) do
        def enabled? = true
      end.new(
        'oms', 'Oms',
        { orchestration: { root_path: directory, sent_path: 'sent', queue: { path: :sent_path } } },
        nil
      )

      DslCatalog.stub(:grouped, { 'print_2_mail_billing_data' => [entry] }, &block)
    end
  end
end
