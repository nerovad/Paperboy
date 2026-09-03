# frozen_string_literal: true

require 'test_helper'

class NoticeOfChangeFormsControllerTest < ActionController::TestCase
  tests Forms::NoticeOfChangeFormsController

  setup do
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com' }
    @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    @controller.define_singleton_method(:inbox_count) { 0 }
  end

  test 'returns all accounting dropdown options for an agency' do
    options = {
      object: [{ label: '2100 - Professional Services', value: 2100 }],
      activity: [{ label: 'IT - Information Technology', value: 'IT' }],
      function: [], program: [], phase: [], task: []
    }
    lookup = Struct.new(:all).new(options)
    factory = lambda do |agency_id:, restrict_to_agency:|
      assert_equal 'GSA', agency_id
      assert restrict_to_agency
      lookup
    end

    Coa::BillingOptions.stub(:new, factory) do
      get :accounting_options, params: { agency_id: 'GSA' }
    end

    assert_response :success
    assert_equal JSON.parse(options.to_json), response.parsed_body
  end
end
