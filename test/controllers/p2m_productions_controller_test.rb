# frozen_string_literal: true

require 'test_helper'

class P2mProductionsControllerTest < ActionController::TestCase
  tests P2m::ProductionsController

  test 'shows printer queues with collapsible file links' do
    sign_in
    queues = [{
      'printer' => 'Printer One', 'queue' => 'Queue A', 'files' => %w[one.pdf two.pdf],
      'modified_at' => Time.zone.local(2026, 9, 4, 10, 30)
    }]
    production_files = Object.new
    production_files.define_singleton_method(:call) { queues }

    P2m::ProductionFiles.stub(:new, production_files) { get :show }

    assert_response :success
    assert_select '.p2m-maildat-row', text: %r{Printer One/Queue A}, count: 1
    assert_select '.p2m-row-trigger[aria-expanded="false"]', count: 1
    assert_select '.p2m-maildat-detail[hidden]', count: 1
    assert_select 'a[data-action="pdf-preview#open"]', count: 2
    assert_select '[data-pdf-preview-target="backdrop"]', count: 1
  end

  test 'previews a production file inline' do
    sign_in
    file = Rails.root.join('test/fixtures/files/p2m-production-preview.pdf')
    file.write('%PDF fixture')
    production_files = Object.new
    production_files.define_singleton_method(:preview) { |**| file }

    P2m::ProductionFiles.stub(:new, production_files) do
      get :preview, params: { printer: 'Printer One', queue: 'Queue A', filename: 'output.pdf' }
    end

    assert_response :success
    assert_equal 'application/pdf', response.media_type
    assert_match 'inline', response.headers.fetch('Content-Disposition')
  ensure
    file&.delete if file&.exist?
  end

  private

  def sign_in
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
    @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
  end
end
