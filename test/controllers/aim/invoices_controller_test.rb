# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

module Aim
  # rubocop:disable Metrics/ClassLength
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

      session[:user] = { 'email' => 'aim.staff@example.com' }
      @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    end

    teardown do
      @old_env.each do |key, value|
        value.nil? ? ENV.delete(key) : ENV[key] = value
      end
      FileUtils.remove_entry(@tmpdir) if @tmpdir && Dir.exist?(@tmpdir)
    end

    test 'vendor review renders official vendor choices and OCR controls' do
      create_vendor_review_invoice(
        'INV-1',
        metadata: { 'VendorName' => 'AIRGAS USA LLC' },
        learn_data: { 'extracted_name' => 'AIRGAS USA LLC' }
      )

      Aim::VendorAliasService.stub(:official_names, ['AIRGAS USA, LLC']) do
        get :show, params: { id: 'INV-1', queue: 'vendor_review' }
      end

      assert_response :success
      assert_select 'input[name=?][readonly=?]', 'aim_extracted_vendor_name', 'readonly'
      assert_select 'select[name=?][data-aim-vendor-select=?]', 'metadata[NormalizedVendor]', 'true'
      assert_select 'input[name=?]', 'normalized_vendor_new'
      refute_includes response.body, 'data-ocr-target-name="metadata[VendorName]"'
      assert_select 'button.btn-ocr[data-ocr-target-name=?]', 'normalized_vendor_new'
      assert_select 'input[type=submit][value=?]', 'Learn & Continue'
      assert_select 'input[type=submit][value=?]', 'Learn & Retry AI'
      assert_select 'button[disabled]', text: 'Check Duplicates *'
      assert_select 'option[value=?]', 'AIRGAS USA, LLC'
      assert_includes response.body, 'AIRGAS USA LLC'
    end

    test 'vendor review hides pipeline plumbing fields from the metadata grid' do
      create_vendor_review_invoice(
        'INV-4',
        metadata: {
          'BU' => '4601',
          'InvoiceNumber' => 'INV-40',
          'ExtractedMetadata' => '{"vendor_name":"AIR GAS"}',
          'Status' => 'Vendor Review',
          'ErrorMessage' => 'Unknown vendor: AIR GAS',
          'InvoiceConcatID' => 'INV-4'
        }
      )

      Aim::VendorAliasService.stub(:official_names, []) do
        get :show, params: { id: 'INV-4', queue: 'vendor_review' }
      end

      assert_response :success
      assert_select 'input[name=?]', 'metadata[InvoiceNumber]'
      Aim::InvoicesHelper::VENDOR_REVIEW_HIDDEN_FIELDS.each do |field|
        next if field == 'NormalizedVendor'

        assert_select 'input[name=?]', "metadata[#{field}]", false, "#{field} must not render as an editable input"
      end
    end

    test 'vendor review ignores protected fields posted back by the form' do
      create_vendor_review_invoice(
        'INV-5',
        metadata: {
          'BU' => '4601',
          'Status' => 'Vendor Review',
          'ErrorMessage' => 'Unknown vendor: AIR GAS',
          'InvoiceConcatID' => 'INV-5',
          'ExtractedMetadata' => '{"vendor_name":"AIR GAS"}',
          'VendorName' => 'AIR GAS'
        }
      )

      patch :update, params: {
        id: 'INV-5',
        queue: 'vendor_review',
        commit: 'Save Changes',
        metadata: {
          'BU' => '4602',
          'Status' => 'TAMPERED',
          'ErrorMessage' => 'TAMPERED',
          'InvoiceConcatID' => 'TAMPERED',
          'ExtractedMetadata' => 'TAMPERED',
          'VendorName' => 'TAMPERED VENDOR'
        }
      }

      metadata = JSON.parse(File.read(File.join(vendor_review_dir, 'INV-5', 'INV-5.json')))
      assert_equal '4602', metadata['BU'], 'ordinary metadata should still be writable'
      assert_equal 'Vendor Review', metadata['Status']
      assert_equal 'Unknown vendor: AIR GAS', metadata['ErrorMessage']
      assert_equal 'INV-5', metadata['InvoiceConcatID']
      assert_equal '{"vendor_name":"AIR GAS"}', metadata['ExtractedMetadata']
      assert_equal 'AIR GAS', metadata['VendorName']
    end

    test 'learn and continue writes SQL-ready payload and routes to ready to learn' do
      create_vendor_review_invoice(
        'INV-2',
        metadata: {
          'FileName' => 'source.pdf',
          'Submitter' => 'Test User',
          'BU' => '4621',
          'VendorName' => 'AIR GAS',
          'InvoiceNumber' => 'INV-20',
          'InvoiceTotal' => '42.50',
          'InvoiceDate' => '2026-08-05'
        }
      )

      learned_aliases = []
      Aim::VendorAliasService.stub(:learn!, ->(**kwargs) { learned_aliases << kwargs }) do
        patch :update, params: {
          id: 'INV-2',
          queue: 'vendor_review',
          commit: 'Learn & Continue',
          metadata: {
            'VendorName' => 'TAMPERED VENDOR',
            'NormalizedVendor' => 'AIRGAS USA, LLC',
            'InvoiceTotal' => '42.50'
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
      assert_equal 'continue_processing', learn_data['next_action']

      ready_payload = JSON.parse(File.read(File.join(moved_folder, 'INV-2_READY_FOR_SQL.json')))
      assert_equal 'AIRGAS USA, LLC', ready_payload['VendorName']
      assert_equal 'INV-20', ready_payload['InvoiceNumber']
      assert_equal '42.50', ready_payload['InvoiceTotal']
      assert_equal 'SUCCESS', ready_payload['Status']
      refute File.exist?(File.join(moved_folder, 'INV-2.json'))
    end

    test 'learn alias prefers a new official vendor name when entered' do
      create_vendor_review_invoice(
        'INV-3',
        metadata: { 'BU' => '4601', 'Submitter' => 'Test User', 'VendorName' => 'TEAM PLAY' }
      )

      learned_aliases = []
      Aim::VendorAliasService.stub(:learn!, ->(**kwargs) { learned_aliases << kwargs }) do
        patch :update, params: {
          id: 'INV-3',
          queue: 'vendor_review',
          commit: 'Learn & Retry AI',
          normalized_vendor_new: 'Team Play Events',
          metadata: {
            'VendorName' => 'TEAM PLAY',
            'NormalizedVendor' => 'Wrong Existing Vendor'
          }
        }
      end

      assert_redirected_to aim_invoices_path(queue: 'vendor_review')
      assert_equal 'Team Play Events', learned_aliases.first[:normalized_name]
      moved_folder = File.join(ready_to_learn_dir, 'INV-3')
      learn_data = JSON.parse(File.read(File.join(moved_folder, 'INV-3_LEARN.json')))
      assert_equal 'retry_ai', learn_data['next_action']
      retry_sidecar = JSON.parse(File.read(File.join(moved_folder, 'INV-3.json')))
      assert_equal '4601', retry_sidecar['bu']
      assert_equal 'Test User', retry_sidecar['submitter']
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
  # rubocop:enable Metrics/ClassLength
end
