# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

module Aim
  # Upload does exactly what intake does: the PDF goes to the store under a
  # fresh batch id and one row is inserted as received with the extract
  # command. AIM v2.
  class UploadsControllerTest < ActionController::TestCase
    tests Aim::UploadsController

    AIM_ENV = %w[AIM_WINDOWS_QUEUE_BASE_PATH AIM_LINUX_QUEUE_BASE_PATH AIM_STORE_DIR].freeze

    setup do
      @tmpdir = Dir.mktmpdir
      @old_env = AIM_ENV.to_h { |key| [key, ENV.fetch(key, nil)] }
      ENV['AIM_WINDOWS_QUEUE_BASE_PATH'] = 'E:\AIM'
      ENV['AIM_LINUX_QUEUE_BASE_PATH'] = @tmpdir
      ENV['AIM_STORE_DIR'] = 'E:\AIM\_BACK_END\_STORE'
      session[:user] = { 'email' => 'jane@example.com', 'employee_id' => 42, 'first_name' => 'Jane',
                         'last_name' => 'Doe', 'unit' => '4601' }
      @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    end

    teardown do
      @old_env.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
      FileUtils.remove_entry(@tmpdir) if @tmpdir && Dir.exist?(@tmpdir)
    end

    def pdf(name)
      Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4 #{name}\n"), 'application/pdf', original_filename: name)
    end

    test 'the form defaults the budget unit to the signed-in user\'s unit' do
      get :new

      assert_response :success
      assert_select 'input[name=budget_unit][value=?]', '4601'
    end

    test 'uploading stores the pdf and inserts the row as intake would' do
      post :create, params: { budget_unit: '4601', owner: 'self', files: [pdf('Scan 001.pdf')] }

      assert_redirected_to aim_invoices_path(queue: 'received')
      row = Aim::Invoice.sole
      assert_match(/\A4601\.\d{8}_\d{6}\.Scan 001-\[[A-Z0-9]{4}\]\z/, row.batch_id)
      assert_equal %w[received extract], [row.state, row.command]
      assert_equal ['4601', 'Jane Doe', 'Jane Doe', 'upload', 'Scan 001.pdf'],
                   [row.budget_unit, row.submitter, row.assigned_to, row.assignment_source, row.source_filename]
      assert File.exist?(File.join(@tmpdir, '_BACK_END', '_STORE', row.batch_id, "#{row.batch_id}.pdf"))
      assert_equal 64, row.content_hash.length
      assert_equal 'jane@example.com', row.events.first.actor
    end

    test 'the shared queue has no owner' do
      post :create, params: { budget_unit: '4601', owner: 'shared', files: [pdf('a.pdf')] }

      row = Aim::Invoice.sole
      assert_nil row.assigned_to
      assert_nil row.assignment_source
    end

    test 'a named person owns it' do
      post :create, params: { budget_unit: '4601', owner: 'person', owner_name: ' Dana Reyes ', files: [pdf('a.pdf')] }

      assert_equal 'Dana Reyes', Aim::Invoice.sole.assigned_to
    end

    test 'several files become several invoices' do
      post :create, params: { budget_unit: '4601', files: [pdf('a.pdf'), pdf('b.pdf')] }

      assert_equal 2, Aim::Invoice.count
    end

    test 'a bad budget unit, no file, or a non-pdf is refused' do
      post :create, params: { budget_unit: '46', files: [pdf('a.pdf')] }
      assert_redirected_to new_aim_upload_path
      assert_match(/budget unit/, flash[:alert])

      post :create, params: { budget_unit: '4601' }
      assert_match(/at least one PDF/, flash[:alert])

      word = Rack::Test::UploadedFile.new(StringIO.new('doc'), 'application/msword', original_filename: 'a.doc')
      post :create, params: { budget_unit: '4601', files: [word] }
      assert_match(/Only PDF/, flash[:alert])
      assert_equal 0, Aim::Invoice.count
    end

    test 'a store that is not configured is reported, not a crash' do
      ENV.delete('AIM_STORE_DIR')

      post :create, params: { budget_unit: '4601', files: [pdf('a.pdf')] }

      assert_redirected_to new_aim_upload_path
      assert_match(/could not be stored/, flash[:alert])
      assert_equal 0, Aim::Invoice.count
    end
  end
end
