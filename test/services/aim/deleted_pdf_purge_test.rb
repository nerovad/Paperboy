# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

module Aim
  # Purging deleted invoices' PDFs after the retention period (#170): only
  # Deleted, only past the period, only once; the row and its history stay.
  class DeletedPdfPurgeTest < ActiveSupport::TestCase
    Folders = Struct.new(:store_dir, :deleted_dir)

    setup do
      @root = Dir.mktmpdir
      @folders = Folders.new(File.join(@root, 'store'), File.join(@root, 'deleted'))
      @old_env = %w[AIM_PURGE_DELETED_PDFS AIM_DELETED_PDF_RETENTION_DAYS].to_h { |key| [key, ENV.fetch(key, nil)] }
      @old_env.each_key { |key| ENV.delete(key) }
    end

    teardown do
      @old_env.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
      FileUtils.remove_entry(@root)
    end

    def invoice(batch_id, state: 'deleted', days_ago: 100, files: %w[pdf stamped.pdf xml], copy: true)
      row = Aim::Invoice.create!(batch_id: batch_id, state: state, actor: 'aim.staff@example.com', budget_unit: '4601',
                                 vendor_name: 'ACME', invoice_number: 'N-1', invoice_total: 10)
      row.update_columns(finished_at: days_ago.days.ago)
      FileUtils.mkdir_p(File.join(@folders.store_dir, batch_id))
      files.each { |ext| File.write(File.join(@folders.store_dir, batch_id, "#{batch_id}.#{ext}"), 'x') }
      if copy
        FileUtils.mkdir_p(File.join(@folders.deleted_dir, batch_id))
        File.write(File.join(@folders.deleted_dir, batch_id, "#{batch_id}.pdf"), 'x')
      end
      row
    end

    def purge = Aim::DeletedPdfPurge.new(directories: @folders)

    def stored(row) = Dir.children(File.join(@folders.store_dir, row.batch_id)).sort

    test 'only deleted invoices past the period are due; rejected ones never' do
      old = invoice('OLD')
      invoice('RECENT', days_ago: 10)
      invoice('REJECTED', state: 'rejected', days_ago: 400)
      undated = invoice('UNDATED')
      undated.update_columns(finished_at: nil, updated_at: 200.days.ago)

      assert_equal %w[OLD UNDATED], purge.due.order(:batch_id).pluck(:batch_id)
      ENV['AIM_DELETED_PDF_RETENTION_DAYS'] = '5'
      assert_includes purge.due.pluck(:batch_id), 'RECENT'
      assert_equal 90, Aim::DeletedPdfPurge::DEFAULT_RETENTION_DAYS
      assert old
    end

    test 'a purge removes the PDFs and the deleted copy, keeps the row, and says so; a second run does nothing' do
      row = invoice('GO')

      assert_equal 1, purge.run
      row.reload
      assert row.pdf_purged_at
      assert_equal ['GO.xml'], stored(row)
      assert_not Dir.exist?(File.join(@folders.deleted_dir, 'GO')), 'the emptied deleted copy folder is removed'
      event = row.events.last
      assert_equal %w[pdf_purged aim], [event.action, event.actor]
      assert_match(/after 90 days in Deleted \(3 files removed\)/, event.note)
      assert_equal %w[ACME N-1 deleted], [row.vendor_name, row.invoice_number, row.state]

      assert_equal 0, purge.run
      assert_equal 1, row.events.where(action: 'pdf_purged').count
    end

    test 'a file already gone is not an error, and an odd batch id is never touched' do
      gone = invoice('GONE', files: [], copy: false)
      odd = invoice('ODD')
      odd.update_columns(batch_id: '../ODD')

      assert_equal 0, purge.purge(gone)
      assert_nil purge.purge(odd)
      assert_match(/no file was left/, gone.events.last.note)
      assert_nil odd.reload.pdf_purged_at
    end

    test 'a purged invoice cannot be restored' do
      row = invoice('KEEP')
      assert row.restorable?

      purge.purge(row)
      assert_not row.reload.restorable?
    end

    test 'the nightly job does nothing until AIM_PURGE_DELETED_PDFS=on' do
      row = invoice('NIGHT')
      directories = @folders
      Aim::InvoiceDirectoryService.stub(:instance, directories) do
        Aim::PurgeDeletedPdfsJob.perform_now
        assert_nil row.reload.pdf_purged_at

        ENV['AIM_PURGE_DELETED_PDFS'] = 'on'
        Aim::PurgeDeletedPdfsJob.perform_now
        assert row.reload.pdf_purged_at
      end
    end
  end
end
