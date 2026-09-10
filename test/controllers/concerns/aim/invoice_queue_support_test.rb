# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

module Aim
  # The AI worker writes more than one JSON into an invoice folder, and
  # Dir.children returns them in the filesystem's order. Picking the first one
  # meant the review screen showed vendor-rule entry fields instead of the
  # invoice. Plan step 1.2.
  #
  # Exercised directly rather than through Aim::InvoicesController: that
  # controller's ACL gate reaches GSABSS, which no test environment has.
  class InvoiceQueueSupportTest < ActiveSupport::TestCase
    class Host
      include Aim::InvoiceQueueSupport

      def initialize(queue)
        @queue = queue
      end

      def metadata_for(folder_path)
        send(:metadata_path_for, folder_path)
      end
    end

    setup do
      @tmpdir = Dir.mktmpdir
    end

    teardown do
      FileUtils.remove_entry(@tmpdir) if @tmpdir && Dir.exist?(@tmpdir)
    end

    test 'a folder holding both files resolves to the payload' do
      folder = invoice_folder('INV-1', 'INV-1_VENDOR_RULE.json' => { 'new_vendor_rule' => '' },
                                       'INV-1_READY_FOR_SQL.json' => { 'InvoiceNumber' => 'INV-10' })

      assert_equal File.join(folder, 'INV-1_READY_FOR_SQL.json'),
                   Host.new('action_needed').metadata_for(folder)
    end

    test 'a vendor-rule sidecar on its own is not metadata' do
      folder = invoice_folder('INV-2', 'INV-2_VENDOR_RULE.json' => { 'new_vendor_rule' => '' })

      assert_nil Host.new('action_needed').metadata_for(folder)
    end

    test 'the payload wins regardless of listing order' do
      folder = invoice_folder('INV-3', 'AAA_VENDOR_RULE.json' => { 'new_vendor_rule' => '' },
                                       'ZZZ_READY_FOR_SQL.json' => { 'InvoiceNumber' => 'INV-30' })

      assert_equal File.join(folder, 'ZZZ_READY_FOR_SQL.json'),
                   Host.new('action_needed').metadata_for(folder)
    end

    test 'a single plain payload is still found' do
      folder = invoice_folder('INV-4', 'INV-4.json' => { 'VendorName' => 'AIRGAS USA, LLC' })

      assert_equal File.join(folder, 'INV-4.json'),
                   Host.new('vendor_review').metadata_for(folder)
    end

    test 'the learn sidecar and the claim file are still ignored' do
      folder = invoice_folder('INV-5', 'INV-5_LEARN.json' => { 'extracted_name' => 'AIR GAS' },
                                       '.claim.json' => { 'email' => 'staff@example.com' })

      assert_nil Host.new('vendor_review').metadata_for(folder)
    end

    private

    def invoice_folder(invoice_id, files)
      folder = File.join(@tmpdir, invoice_id)
      FileUtils.mkdir_p(folder)
      File.write(File.join(folder, "#{invoice_id}.pdf"), 'pdf')
      files.each { |name, body| File.write(File.join(folder, name), JSON.pretty_generate(body)) }
      folder
    end
  end
end
