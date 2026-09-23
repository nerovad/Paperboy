# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

module Aim
  # The queue screens list what the rows say is in a queue, and lose nothing
  # the folders hold. Plan step 5.7b.
  # rubocop:disable Metrics/ClassLength
  class InvoiceQueueListingTest < ActionController::TestCase
    tests Aim::InvoicesController

    QUEUES = { 'AIM_ACTION_NEEDED_DIR' => '_ACTION_NEEDED', 'AIM_REJECTED_DIR' => '_REJECTED' }.freeze
    AIM_ENV = (%w[AIM_WINDOWS_QUEUE_BASE_PATH AIM_LINUX_QUEUE_BASE_PATH] + QUEUES.keys).freeze

    setup do
      @tmpdir = Dir.mktmpdir
      @old_env = AIM_ENV.to_h { |key| [key, ENV.fetch(key, nil)] }
      ENV['AIM_WINDOWS_QUEUE_BASE_PATH'] = 'E:\AIM'
      ENV['AIM_LINUX_QUEUE_BASE_PATH'] = @tmpdir
      QUEUES.each do |variable, folder|
        ENV[variable] = "E:\\AIM\\_BACK_END\\#{folder}"
        FileUtils.mkdir_p(File.join(@tmpdir, '_BACK_END', folder))
      end
      session[:user] = { 'email' => 'aim.staff@example.com', 'employee_id' => 42 }
      @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    end

    teardown do
      @old_env.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
      FileUtils.remove_entry(@tmpdir) if @tmpdir && Dir.exist?(@tmpdir)
    end

    def folder(batch_id, queue: '_ACTION_NEEDED', group: nil, payload: {})
      path = File.join(*[@tmpdir, '_BACK_END', queue, group, batch_id].compact)
      FileUtils.mkdir_p(path)
      File.write(File.join(path, "#{batch_id}.pdf"), 'pdf')
      File.write(File.join(path, "#{batch_id}_READY_FOR_SQL.json"), JSON.pretty_generate(payload))
      path
    end

    def row(batch_id, state: 'action_needed', **facts)
      Aim::Invoice.create!(batch_id: batch_id, state: state, actor: 'watcher', **facts)
    end

    def listed_row(batch_id)
      css_select('tr').find { |tr| tr['title'] == batch_id }
    end

    test 'an invoice with a row and a folder is listed' do
      folder('4601.A', payload: { 'InvoiceNumber' => 'INV-1' })
      row('4601.A')

      get :index, params: { queue: 'action_needed' }

      assert listed_row('4601.A')
      assert_not_includes response.body, 'Not yet recorded'
    end

    test 'the row fills in what the folder does not say' do
      folder('4601.B', payload: { 'InvoiceNumber' => 'INV-2' })
      row('4601.B', vendor_name: 'ACME SUPPLY', invoice_total: '134.69', budget_unit: '4601')

      get :index, params: { queue: 'action_needed' }

      line = listed_row('4601.B').text
      assert_includes line, 'ACME SUPPLY'
      assert_includes line, '4601'
      assert_includes line, '134.69'
    end

    test 'what a reviewer saved in the folder beats the row' do
      folder('4601.C', payload: { 'InvoiceNumber' => 'CORRECTED-3', 'VendorName' => 'REVIEWED VENDOR' })
      row('4601.C', invoice_number: 'AS-EXTRACTED', vendor_name: 'AI VENDOR')

      get :index, params: { queue: 'action_needed' }

      line = listed_row('4601.C').text
      assert_includes line, 'CORRECTED-3'
      assert_includes line, 'REVIEWED VENDOR'
      assert_not_includes line, 'AS-EXTRACTED'
    end

    test 'a folder with no row is still listed, flagged' do
      folder('4601.D')

      get :index, params: { queue: 'action_needed' }

      assert listed_row('4601.D')
      assert_includes listed_row('4601.D').text, 'Not yet recorded'
    end

    test 'a row whose folder has gone is listed, not hidden' do
      row('4601.E')

      get :index, params: { queue: 'action_needed' }

      line = listed_row('4601.E').text
      assert_includes line, 'Files missing'
      assert_includes line, 'Files not found on the share'
    end

    test 'a row in another state is not listed' do
      row('4601.F', state: 'sql_queue')

      get :index, params: { queue: 'action_needed' }

      assert_nil listed_row('4601.F')
    end

    test 'a rejected queue lists invoices, not the groups they are filed under' do
      folder('4601.G', queue: '_REJECTED', group: 'Jane Doe_4601')
      row('4601.G', state: 'rejected')

      get :index, params: { queue: 'rejected' }

      assert listed_row('4601.G')
      assert_nil listed_row('Jane Doe_4601')
    end

    test 'a rejected invoice opens from its group folder' do
      folder('4601.H', queue: '_REJECTED', group: 'Jane Doe_4601', payload: { 'InvoiceNumber' => 'INV-8' })
      row('4601.H', state: 'rejected')

      get :show, params: { id: '4601.H', queue: 'rejected' }

      assert_response :success
    end

    test 'without the rows the list comes from the folders and says so' do
      folder('4601.I')

      Aim::Invoice.stub(:where, ->(*) { raise ActiveRecord::ConnectionNotEstablished }) do
        get :index, params: { queue: 'action_needed' }
      end

      assert listed_row('4601.I')
      assert_includes response.body, 'could not be read'
    end
  end
  # rubocop:enable Metrics/ClassLength
end
