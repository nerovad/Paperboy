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
      assert_select 'select[name=budget_unit] option[selected][value=?]', '4601'
    end

    test 'uploading stores the pdf and inserts the row as intake would' do
      post :create, params: { budget_unit: '4601', owner: 'self', files: [pdf('Scan 001.pdf')] }

      assert_redirected_to new_aim_upload_path, 'stays on the upload page, which everyone can reach'
      row = Aim::Invoice.sole
      assert_match(/\A4601\.\d{8}_\d{6}\.Scan 001-\[[A-Z0-9]{4}\]\z/, row.batch_id)
      assert_equal %w[received extract], [row.state, row.command]
      assert_equal ['4601', 'Jane Doe', 'upload', 'Scan 001.pdf'],
                   [row.budget_unit, row.submitter, row.assignment_source, row.source_filename]
      assert_equal 42, row.assigned_employee_id, "the uploader's own queue, by employee id"
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

    test 'a person picked by employee id owns it' do
      employee = Employee.order(:id).first || skip('no employee to test with')

      params = { budget_unit: '4601', owner: 'person', owner_employee_id: employee.id, files: [pdf('a.pdf')] }
      Aim::Users.stub(:member?, true) { Aim::Users.stub(:budget_units_of, ['4601']) { post :create, params: params } }

      row = Aim::Invoice.sole
      assert_equal [employee.id, "#{employee.first_name} #{employee.last_name}".squish],
                   [row.assigned_employee_id, row.assigned_to]
    end

    test 'several files become several invoices' do
      post :create, params: { budget_unit: '4601', files: [pdf('a.pdf'), pdf('b.pdf')] }

      assert_equal 2, Aim::Invoice.count
    end

    test 'a bad budget unit, no file, or a non-pdf is refused' do
      post :create, params: { budget_unit: '46', files: [pdf('a.pdf')] }
      assert_redirected_to new_aim_upload_path
      assert_match(/budget unit/, flash[:alert])

      post :create, params: { budget_unit: '9999', files: [pdf('a.pdf')] }
      assert_match(/budget unit/, flash[:alert], 'four digits that are not a COA unit are refused too')

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
      assert_match(/could not be saved/, flash[:alert])
      assert_equal 0, Aim::Invoice.count
    end

    test 'someone else is found with the employee search' do
      get :new

      assert_select 'select[name=owner_employee_id][data-controller=aim-grouped-search]'
      assert_select '[data-controller~=aim-dropzone] input[type=file][multiple]'
    end

    test 'someone else with nobody picked is refused, not sent to the shared queue' do
      post :create, params: { budget_unit: '4601', owner: 'person', owner_employee_id: '', files: [pdf('a.pdf')] }

      assert_match(/Choose the person/, flash[:alert])
      assert_equal 0, Aim::Invoice.count
    end

    test 'someone with no queue of their own starts on someone else, and has no Mine' do
      @controller.define_singleton_method(:current_user_group_names) { Set[] }
      Aim::Users.stub(:member?, false) { get :new }

      assert_select 'input[type=radio][name=owner][value=self]', 0
      assert_select 'input[type=radio][name=owner][value=person][checked]'
    end

    test 'an invoice cannot be sent to someone who does not work AIM' do
      Aim::Users.stub(:member?, false) do
        post :create, params: { budget_unit: '4601', owner: 'person', owner_employee_id: '12345', files: [pdf('a.pdf')] }
      end

      assert_match(/is not in AIM/, flash[:alert])
      assert_equal 0, Aim::Invoice.count
    end
  end
end
