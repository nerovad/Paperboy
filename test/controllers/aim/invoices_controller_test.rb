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
      AIM_ACTION_NEEDED_DIR
    ].freeze

    setup do
      @tmpdir = Dir.mktmpdir
      @old_env = AIM_ENV.to_h { |key| [key, ENV.fetch(key, nil)] }

      ENV['AIM_WINDOWS_QUEUE_BASE_PATH'] = 'E:\AIM'
      ENV['AIM_LINUX_QUEUE_BASE_PATH'] = @tmpdir
      ENV['AIM_VENDOR_REVIEW_DIR'] = 'E:\AIM\_BACK_END\_VENDOR_REVIEW'
      ENV['AIM_READY_TO_LEARN_DIR'] = 'E:\AIM\_BACK_END\_READY_TO_LEARN'
      ENV['AIM_ACTION_NEEDED_DIR'] = 'E:\AIM\_BACK_END\_ACTION_NEEDED'

      FileUtils.mkdir_p(vendor_review_dir)
      FileUtils.mkdir_p(ready_to_learn_dir)
      FileUtils.mkdir_p(action_needed_dir)

      # current_user is nil unless the session carries BOTH keys, and a nil
      # current_user fails require_app_access before any AIM code runs. Every
      # test in this file used to 302 to / for want of the employee_id.
      session[:user] = { 'email' => 'aim.staff@example.com', 'employee_id' => 42 }
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

    test 'action needed renders the payload, not the vendor-rule sidecar' do
      create_action_needed_invoice(
        'INV-5',
        payload: { 'VendorName' => 'AIRGAS USA, LLC', 'InvoiceNumber' => 'INV-50' },
        vendor_rule: { 'vendor_name' => 'AIRGAS USA, LLC', 'new_vendor_rule' => '' }
      )

      get :show, params: { id: 'INV-5', queue: 'action_needed' }

      assert_response :success
      assert_includes response.body, 'INV-50'
      refute_includes response.body, 'new_vendor_rule'
    end

    # Plan step 2.1. A claim used to count merely by existing, so a second
    # reviewer opening someone else's invoice got the whole action strip.
    test 'an invoice claimed by someone else renders read only' do
      folder = create_action_needed_invoice('INV-6', payload: { 'InvoiceNumber' => 'INV-60' },
                                                     vendor_rule: {})
      write_claim(folder, 'other.staff@example.com', name: 'Dana Reyes')

      get :show, params: { id: 'INV-6', queue: 'action_needed' }

      assert_response :success
      assert_includes response.body, 'Dana Reyes claimed this invoice'
      assert_select 'input[type=submit][value=?]', 'Save Changes', false
      assert_select 'input[type=submit][value=?]', 'Unclaim', false
      assert_select 'a', text: 'Return to Queue'
    end

    test 'the reviewer holding the claim resumes it freely' do
      folder = create_action_needed_invoice('INV-7', payload: { 'InvoiceNumber' => 'INV-70' },
                                                     vendor_rule: {})
      write_claim(folder, 'AIM.Staff@Example.com')

      get :show, params: { id: 'INV-7', queue: 'action_needed' }

      assert_response :success
      assert_select 'input[type=submit][value=?]', 'Save Changes'
      refute_includes response.body, 'Read only'
      assert_equal 'AIM.Staff@Example.com', JSON.parse(File.read(claim_path(folder)))['user']
    end

    test 'an unclaimed invoice is claimed for the signed-in reviewer' do
      folder = create_action_needed_invoice('INV-8', payload: { 'InvoiceNumber' => 'INV-80' },
                                                     vendor_rule: {})

      get :show, params: { id: 'INV-8', queue: 'action_needed' }

      assert_response :success
      assert_equal 'aim.staff@example.com', JSON.parse(File.read(claim_path(folder)))['user']
      assert_select 'input[type=submit][value=?]', 'Save Changes'
    end

    test 'a foreign claim refuses a posted save' do
      folder = create_action_needed_invoice('INV-9', payload: { 'InvoiceNumber' => 'INV-90' },
                                                     vendor_rule: {})
      write_claim(folder, 'other.staff@example.com')

      patch :update, params: { id: 'INV-9', queue: 'action_needed', commit: 'Save Changes',
                               metadata: { 'InvoiceNumber' => 'REWRITTEN' } }

      assert_redirected_to aim_invoices_path(queue: 'action_needed')
      assert_match(/view only/, flash[:alert])
      payload = JSON.parse(File.read(File.join(folder, 'INV-9_READY_FOR_SQL.json')))
      assert_equal 'INV-90', payload['InvoiceNumber']
    end

    test 'a foreign claim cannot be released by someone else' do
      folder = create_action_needed_invoice('INV-10', payload: { 'InvoiceNumber' => 'INV-100' },
                                                      vendor_rule: {})
      write_claim(folder, 'other.staff@example.com')

      patch :update, params: { id: 'INV-10', queue: 'action_needed', commit: 'Unclaim' }

      assert_redirected_to aim_invoices_path(queue: 'action_needed')
      assert_path_exists claim_path(folder)
    end

    test 'a foreign claim refuses an AI retry' do
      folder = create_action_needed_invoice('INV-11', payload: { 'InvoiceNumber' => 'INV-110' },
                                                      vendor_rule: {})
      write_claim(folder, 'other.staff@example.com')

      post :retry, params: { id: 'INV-11', queue: 'action_needed' }

      assert_redirected_to aim_invoices_path(queue: 'action_needed')
      assert_path_exists folder
    end

    test 'the queue offers view only for an invoice someone else holds' do
      own = create_action_needed_invoice('INV-12', payload: { 'InvoiceNumber' => 'INV-120' },
                                                   vendor_rule: {})
      other = create_action_needed_invoice('INV-13', payload: { 'InvoiceNumber' => 'INV-130' },
                                                     vendor_rule: {})
      # Mixed case on our own claim: the queue and the review page have to
      # agree on who a claimant is, and the pfa work provider already ignores
      # case, so this row must read Resume Review rather than View Only.
      write_claim(own, 'AIM.Staff@Example.com')
      write_claim(other, 'other.staff@example.com', name: 'Dana Reyes')

      get :index, params: { queue: 'action_needed' }

      assert_response :success
      assert_select 'tr.is-locked', 1
      assert_select 'a', text: 'View Only'
      assert_select 'a', text: 'Resume Review'
      assert_includes response.body, 'Claimed by Dana Reyes'
    end

    private

    def create_action_needed_invoice(invoice_id, payload:, vendor_rule:)
      folder_path = File.join(action_needed_dir, invoice_id)
      FileUtils.mkdir_p(folder_path)
      File.write(File.join(folder_path, "#{invoice_id}.pdf"), 'pdf')
      File.write(File.join(folder_path, "#{invoice_id}_VENDOR_RULE.json"),
                 JSON.pretty_generate(vendor_rule))
      File.write(File.join(folder_path, "#{invoice_id}_READY_FOR_SQL.json"),
                 JSON.pretty_generate(payload))
      folder_path
    end

    def write_claim(folder_path, email, name: nil)
      claim = { 'user' => email, 'timestamp' => Time.zone.now.to_i }
      claim['name'] = name if name
      File.write(claim_path(folder_path), JSON.pretty_generate(claim))
    end

    def claim_path(folder_path)
      File.join(folder_path, '.claim.json')
    end

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

    def action_needed_dir
      Aim::InvoiceDirectoryService.instance.path_for('action_needed')
    end
  end
  # rubocop:enable Metrics/ClassLength
end
