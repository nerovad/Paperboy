# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

module Aim
  # Edit PDF (#181): swap or edit an invoice's PDF at once; the old one kept,
  # the history told, an approved one stamped again.
  class PdfEditsTestCase < ActionController::TestCase
    tests Aim::PdfEditsController

    setup do
      @store = Dir.mktmpdir
      session[:user] = { 'email' => 'aim.staff@example.com', 'employee_id' => 42 }
      @controller.define_singleton_method(:current_user_group_names) { Set['aim_admin'] }
      @controller.helpers.define_singleton_method(:can_access_app?) { |*| true }
    end

    teardown { FileUtils.rm_rf(@store) }

    def in_store(&block) = Aim::InvoiceDirectoryService.instance.stub(:store_dir, @store, &block)

    def invoice(state: 'needs_review', pages: 3)
      row = Aim::Invoice.create!(batch_id: '4641.20260924_104420.Vendor invoice-[WY3C]', state: state, actor: 'aim_worker', vendor_name: 'ACME', invoice_number: 'N-1',
                                 budget_unit: '4641', page_count: pages)
      write_pdf(row.pdf_path, 'orig', pages)
      row
    end

    def write_pdf(path, name, pages)
      FileUtils.mkdir_p(File.dirname(path))
      Prawn::Document.generate(path) do |doc|
        pages.times do |index|
          doc.start_new_page if index.positive?
          doc.text "#{name} page #{index + 1}"
        end
      end
      path
    end

    def upload(name, pages)
      Rack::Test::UploadedFile.new(write_pdf(File.join(@store, "#{name}.pdf"), name, pages), 'application/pdf', original_filename: "#{name}.pdf")
    end

    def texts(path) = PDF::Reader.new(path).pages.map { |page| page.text.squish }
  end

  # Swapping and editing.
  class PdfEditsControllerTest < PdfEditsTestCase
    test 'a swap takes effect at once, keeps the old PDF as a version and says so' do
      in_store do
        row = invoice
        post :replace, params: { id: row.batch_id, file: upload('fixed', 2) }

        assert_redirected_to aim_invoice_path(row.batch_id, queue: 'needs_review')
        assert_equal ['fixed page 1', 'fixed page 2'], texts(row.pdf_path)
        assert_equal ['orig page 1', 'orig page 2', 'orig page 3'], texts(File.join(row.store_dir, "#{row.batch_id}.v1.pdf"))
        row.reload
        assert_equal [2, 'needs_review'], [row.page_count, row.state]
        assert_match(/PDF swapped for fixed.pdf; previous PDF kept as version 1/, row.events.last.note)

        post :replace, params: { id: row.batch_id, file: upload('again', 1) }
        assert_equal [1, 2], Aim::PdfVersions.kept(row).map(&:first), 'a batch id ending in [WY3C] still finds its versions'
        assert_match(/kept as version 2/, row.reload.events.last.note)
      end
    end

    test 'edits apply at once: reorder, remove, turn, and pages from another PDF' do
      in_store do
        row = invoice
        pages = [{ source: 0, page: 3, rotate: 90 }, { source: 1, page: 1 }, { source: 0, page: 1 }]
        patch :update, params: { id: row.batch_id, pages: pages.to_json, inserts: [upload('extra', 1)] }

        assert_equal 'PDF changes applied.', flash[:notice]
        reader = PDF::Reader.new(row.pdf_path)
        assert_equal ['extra page 1', 'orig page 1'], texts(row.pdf_path).drop(1)
        assert_equal 90, reader.pages.first.attributes[:Rotate]
        note = row.events.last.note
        assert_match(/removed page 2/, note)
        assert_match(/added 1 page from extra.pdf/, note)
        assert_match(/rotated page 3/, note)
        assert_match(/version 1/, note)
      end
    end

    test 'a bad edit or file changes nothing and says why' do
      in_store do
        row = invoice
        before = File.binread(row.pdf_path)
        patch :update, params: { id: row.batch_id, pages: [{ source: 0, page: 9 }].to_json }
        assert_match(/Not applied: page 9 is not in that PDF/, flash[:alert])

        post :replace, params: { id: row.batch_id, file: Rack::Test::UploadedFile.new(StringIO.new('hello'), 'application/pdf', original_filename: 'x.pdf') }
        assert_match(/x.pdf is not a PDF/, flash[:alert])
        assert_equal before, File.binread(row.pdf_path)
        assert_empty Aim::PdfVersions.kept(row)
      end
    end

    test 'Read it again with the AI sends it back to the AI only when asked' do
      in_store do
        row = invoice
        post :replace, params: { id: row.batch_id, file: upload('fixed', 1), reread: '1' }
        assert_equal %w[received extract], [row.reload.state, row.command]
      end
    end
  end

  # When and by whom the PDF may change.
  class PdfEditsAccessTest < PdfEditsTestCase
    test 'an approved invoice can be edited and is stamped again' do
      in_store do
        row = invoice(state: 'approved')
        row.events.create!(action: 'transition', from_state: 'ready_for_approval', to_state: 'approved', actor: 'approver@example.com')
        record = Aim::FiscalRecord.create!(invoice: row)
        post :replace, params: { id: row.batch_id, file: upload('fixed', 1) }
        assert File.exist?(Aim::ApprovalStamp.path(row)), 'stamped again'
        assert_not_nil record.reload.stamped_at
        assert_match(/changed after approval/, row.events.last.note)
      end
    end

    test 'once Fiscal archives it, or while the AI has it, or once rejected, the editor is shut' do
      in_store do
        row = invoice(state: 'approved')
        record = Aim::FiscalRecord.create!(invoice: row)
        record.update_columns(status: 'archived', archived_at: Time.current)
        get :show, params: { id: row.batch_id }
        assert_redirected_to aim_invoice_path(row.batch_id, queue: row.queue)

        %w[received rejected].each do |state|
          row.update_columns(state: state)
          get :show, params: { id: row.batch_id }
          assert_response :redirect, state
        end
      end
    end

    test 'someone else in the invoice, or no AIM role, keeps the editor shut' do
      in_store do
        row = invoice
        row.claim!('other@example.com', name: 'Other')
        get :show, params: { id: row.batch_id }
        assert_response :redirect

        row.release_claim!
        get :show, params: { id: row.batch_id }
        assert_response :success
        assert_select '[data-controller=aim-pdf-editor][data-aim-pdf-editor-pdf-url-value=?]', aim_pdf_source_invoice_path(row.batch_id)

        @controller.define_singleton_method(:current_user_group_names) { Set[] }
        get :show, params: { id: row.batch_id }
        assert_response :redirect
      end
    end
  end
end
