# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
require 'prawn'

module Aim
  # The Batch Split review page: a person corrects the AI's split and approves
  # it, or says it is one invoice after all. Plan step 5.7c.
  class InvoiceSplitReviewTest < ActionController::TestCase
    tests Aim::InvoicesController

    QUEUES = {
      'AIM_BATCH_SPLIT_DIR' => '_BATCH_SPLIT',
      'AIM_READY_TO_SPLIT_DIR' => '_READY_TO_SPLIT',
      'AIM_REPROCESS_QUEUE_DIR' => '_REPROCESS_QUEUE'
    }.freeze
    AIM_ENV = (%w[AIM_WINDOWS_QUEUE_BASE_PATH AIM_LINUX_QUEUE_BASE_PATH] + QUEUES.keys).freeze
    BATCH = '4601.20260923_120000.Scan 001'

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

    def queue_dir(folder) = File.join(@tmpdir, '_BACK_END', folder)

    def batch(pages: 3, invoices: [{ 'vendor_name' => 'ACME', 'invoice_number' => 'INV-1', 'pages' => [1, 2] },
                                   { 'vendor_name' => 'ACME', 'invoice_number' => 'INV-2', 'pages' => [3] }])
      folder = File.join(queue_dir('_BATCH_SPLIT'), BATCH)
      FileUtils.mkdir_p(folder)
      Prawn::Document.generate(File.join(folder, "#{BATCH}.pdf")) do |pdf|
        pages.times { |index| pdf.start_new_page unless index.zero? }
      end
      manifest = { 'bu' => '4601', 'submitter' => 'Jane Doe', 'owner' => 'Jane Doe', 'invoices' => invoices }
      File.write(File.join(folder, "#{BATCH}_MANIFEST.json"), JSON.pretty_generate(manifest))
      Aim::Invoice.create!(batch_id: BATCH, state: 'batch_split', actor: '01_ai_extraction_worker')
      folder
    end

    def split_params(*rows)
      rows.each_with_index.to_h do |(vendor, number, pages), index|
        [index.to_s, { vendor_name: vendor, invoice_number: number, pages_text: pages }]
      end
    end

    test 'the page shows the proposed invoices, one row each, with their pages' do
      batch

      get :show, params: { id: BATCH, queue: 'batch_split' }

      assert_response :success
      assert_select 'input[name=?][value=?]', 'split[0][pages_text]', '1-2'
      assert_select 'input[name=?][value=?]', 'split[1][pages_text]', '3'
      assert_select 'input[name=?][value=?]', 'split[0][invoice_number]', 'INV-1'
      assert_includes response.body, 'across its 3 pages'
      assert_select 'input[type=submit][value=?]', 'Approve Split'
      assert_select 'input[type=submit][value=?]', 'Process as One Invoice'
    end

    test 'an approved split rewrites the manifest and sends the batch to the splitter' do
      batch

      patch :update, params: { id: BATCH, queue: 'batch_split', commit: 'Approve Split',
                               split: split_params(%w[ACME INV-1 1], %w[ACME INV-2 2-3]) }

      moved = File.join(queue_dir('_READY_TO_SPLIT'), BATCH)
      assert Dir.exist?(moved)
      manifest = JSON.parse(File.read(File.join(moved, "#{BATCH}_MANIFEST.json")))
      assert_equal [[1], [2, 3]], manifest['invoices'].pluck('pages')
      assert_equal ['4601', 'Jane Doe', 'Jane Doe'], manifest.values_at('bu', 'submitter', 'owner'),
                   'what the AI worker recorded about the batch survives the edit'
      assert_equal 'ready_to_split', Aim::Invoice.find_by!(batch_id: BATCH).state
    end

    test 'a split that does not make sense is refused, keeping what was typed' do
      folder = batch

      patch :update, params: { id: BATCH, queue: 'batch_split', commit: 'Approve Split',
                               split: split_params(%w[ACME INV-1 1-2], %w[ACME INV-2 2-3]) }

      assert_response :unprocessable_content
      assert_includes response.body, 'Page 2 is in invoices 1 and 2'
      assert_select 'input[name=?][value=?]', 'split[1][pages_text]', '2-3'
      assert Dir.exist?(folder), 'nothing moves'
      assert_equal 'batch_split', Aim::Invoice.find_by!(batch_id: BATCH).state
    end

    test 'a page past the end of the PDF is refused' do
      batch

      patch :update, params: { id: BATCH, queue: 'batch_split', commit: 'Approve Split',
                               split: split_params(%w[ACME INV-1 1-2], %w[ACME INV-2 3-4]) }

      assert_includes response.body, 'page 4 is not in this 3-page PDF'
    end

    test 'one invoice after all goes back through extraction under its own id' do
      batch

      patch :update, params: { id: BATCH, queue: 'batch_split', commit: 'Process as One Invoice' }

      moved = File.join(queue_dir('_REPROCESS_QUEUE'), BATCH)
      assert Dir.exist?(moved)
      sidecar = JSON.parse(File.read(File.join(moved, "#{BATCH}.json")))
      assert_equal({ 'bu' => '4601', 'submitter' => 'Jane Doe', 'owner' => 'Jane Doe',
                     'bypass_split' => true, 'processing_id' => BATCH }, sidecar)
      assert_equal 'reprocess', Aim::Invoice.find_by!(batch_id: BATCH).state
    end
  end
end
