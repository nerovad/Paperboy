# frozen_string_literal: true

require 'test_helper'

class P2mQualityControlsControllerTest < ActionController::TestCase
  tests P2m::QualityControlsController

  test 'shows the GSAP2M list date' do
    sign_in
    rows = [{ 'omsnumber' => '52543073', 'qc_date' => '2026-10-05T07:14:00' }]

    P2m::QualityControl.stub(:oms_rows, rows) do
      get :show, params: { quality_control: { start_date: '2026-10-01', end_date: '2026-10-07' } }
    end

    assert_response :success
    assert_select 'td', text: '52543073'
    assert_select 'td', text: '2026-10-05'
  end

  test 'keeps printed mailed and UAA visible beside a GSAP2M match' do
    sign_in
    upload = P2m::OmsUpload.new(input_record_count: 9, mailed_record_count: 2, non_mailed_record_count: 7)
    details = {
      oms_number: '52543073',
      upload: upload,
      databases: {
        'GSAP2M' => {
          totals: [4, 4, 4],
          match: true,
          jobs: [{
            job_number: 'RSPBLL',
            sources: [{ row_count: 4 }, { row_count: 4 }, { row_count: 4 }],
            match: true
          }]
        }
      }
    }

    P2m::QualityControl.stub(:details, details) do
      get :details, params: { oms_number: '52543073',
                              quality_control: { start_date: '2026-10-01', end_date: '2026-10-07' } }
    end

    assert_response :success
    assert_select 'td', text: 'GSAP2M'
    assert_select 'td', text: 'GSABSS', count: 0
    assert_select 'td', text: '9'
    assert_select 'td', text: '2'
    assert_select 'td', text: '7'
    assert_select 'td', text: 'Match'
  end

  private

  def sign_in
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
    @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
  end
end
