# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

module Aim
  class InvoicesControllerTest < ActionController::TestCase
    tests Aim::InvoicesController
    AIM_ENV = %w[
      AIM_WINDOWS_QUEUE_BASE_PATH
      AIM_LINUX_QUEUE_BASE_PATH
      AIM_VENDOR_REVIEW_DIR
      AIM_READY_TO_LEARN_DIR
    ].freeze

    setup do
      @tmpdir = Dir.mktmpdir
      @old_env = AIM_ENV.to_h { |key| [key, ENV.fetch(key, nil)] }

      ENV['AIM_WINDOWS_QUEUE_BASE_PATH'] = 'E:\AIM'
      ENV['AIM_LINUX_QUEUE_BASE_PATH'] = @tmpdir
      ENV['AIM_VENDOR_REVIEW_DIR'] = 'E:\AIM\_BACK_END\_VENDOR_REVIEW'
      ENV['AIM_READY_TO_LEARN_DIR'] = 'E:\AIM\_BACK_END\_READY_TO_LEARN'

      FileUtils.mkdir_p(vendor_review_dir)
      FileUtils.mkdir_p(ready_to_learn_dir)

      session[:user] = {
        'employee_id' => 1,
        'email' => 'aim.staff@example.com',
        'first_name' => 'AIM',
        'last_name' => 'Staff'
      }
      @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    end

    teardown do
      @old_env.each do |key, value|
        value.nil? ? ENV.delete(key) : ENV[key] = value
      end
      FileUtils.remove_entry(@tmpdir) if @tmpdir && Dir.exist?(@tmpdir)
    end

    test 'vendor review renders official vendor choices from SQL' do
      create_vendor_review_invoice(
        'INV-1',
        metadata: { 'VendorName' => 'AIRGAS USA LLC' },
        learn_data: { 'extracted_name' => 'AIRGAS USA LLC' }
      )

      Aim::VendorAliasService.stub(:official_names, ['AIRGAS USA, LLC']) do
        get :show, params: { id: 'INV-1', queue: 'vendor_review' }
      end

      assert_response :success
      assert_select 'input[name=?][list=?]', 'metadata[NormalizedVendor]', 'aim-official-vendor-names'
      assert_select 'option[value=?]', 'AIRGAS USA, LLC'
      assert_includes response.body, 'AIRGAS USA LLC'
    end

    test 'learn alias writes to SQL and routes to ready to learn' do
      create_vendor_review_invoice('INV-2', metadata: { 'VendorName' => 'AIR GAS' })

      learned_aliases = []
      Aim::VendorAliasService.stub(:learn!, ->(**kwargs) { learned_aliases << kwargs }) do
        patch :update, params: {
          id: 'INV-2',
          queue: 'vendor_review',
          commit: 'Learn Alias',
          metadata: {
            'VendorName' => 'AIR GAS',
            'NormalizedVendor' => 'AIRGAS USA, LLC'
          }
        }
      end

      assert_redirected_to aim_invoices_path(queue: 'vendor_review')
      assert_equal(
        {
          extracted_name: 'AIR GAS',
          normalized_name: 'AIRGAS USA, LLC',
          learned_by: 'aim.staff@example.com'
        },
        learned_aliases.first
      )

      moved_folder = File.join(ready_to_learn_dir, 'INV-2')
      assert Dir.exist?(moved_folder)
      learn_data = JSON.parse(File.read(File.join(moved_folder, 'INV-2_LEARN.json')))
      assert_equal 'AIR GAS', learn_data['extracted_name']
      assert_equal 'AIRGAS USA, LLC', learn_data['suggested_normalized_name']
    end

    private

    def create_vendor_review_invoice(invoice_id, metadata:, learn_data: {})
      folder_path = File.join(vendor_review_dir, invoice_id)
      FileUtils.mkdir_p(folder_path)
      File.write(File.join(folder_path, "#{invoice_id}.pdf"), 'pdf')
      File.write(File.join(folder_path, "#{invoice_id}.json"), JSON.pretty_generate(metadata))
      return if learn_data.empty?

      File.write(File.join(folder_path, "#{invoice_id}_LEARN.json"), JSON.pretty_generate(learn_data))
    end

    def vendor_review_dir
      Aim::InvoiceDirectoryService.instance.vendor_review_dir
    end

    def ready_to_learn_dir
      Aim::InvoiceDirectoryService.instance.ready_to_learn_dir
    end
  end
end
