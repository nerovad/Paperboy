# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

module Aim
  # What Upload lets in -- a PDF by its content -- and where an invoice for
  # someone away goes.
  class UploadChecksTest < ActionController::TestCase
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

    test 'what the file holds decides, not its name or declared type' do
      renamed = Rack::Test::UploadedFile.new(StringIO.new('just text'), 'application/pdf', original_filename: 'a.pdf')
      post :create, params: { budget_unit: '4601', files: [renamed] }
      assert_match(/Only PDF/, flash[:alert])
      assert_equal 0, Aim::Invoice.count

      unlabelled = Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4 scan\n"), 'application/octet-stream',
                                                original_filename: 'scan')
      post :create, params: { budget_unit: '4601', owner: 'shared', files: [unlabelled] }
      assert_equal 1, Aim::Invoice.count
    end

    test 'an invoice for someone away goes to whoever covers for them' do
      one, two = Employee.order(:id).limit(2).to_a
      skip('needs two employees to test with') unless two
      AwayPeriod.create!(employee_id: one.id.to_s, delegate_id: two.id.to_s, starts_on: Date.current,
                         ends_on: 1.week.from_now.to_date)

      params = { budget_unit: '4601', owner: 'person', owner_employee_id: one.id, files: [pdf('a.pdf')] }
      Aim::Users.stub(:member?, true) { Aim::Users.stub(:budget_units_of, ['4601']) { post :create, params: params } }

      row = Aim::Invoice.sole
      assert_equal [two.id, two.full_name], [row.assigned_employee_id, row.assigned_to]
      assert_equal [one.id.to_s, two.id.to_s, '42'],
                   row.task_reassignments.sole.slice(:from_employee_id, :to_employee_id, :reassigned_by_id).values
    end
  end
end
