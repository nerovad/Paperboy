# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

module Aim
  # Edit PDF (#181, #182): swap, edit or restore an invoice's PDF at once,
  # each a version; the history told, an approved one stamped again.
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

    # A request after a file upload in the same test would inherit its
    # multipart content type; each request here starts plain.
    def process(...)
      %w[CONTENT_TYPE RAW_POST_DATA].each { |header| @request.delete_header(header) }
      super
    end
  end

  # Swapping, editing and versions (#181, #182).
  class PdfEditsControllerTest < PdfEditsTestCase
    def versions(row) = Aim::PdfVersions.all(row).map { |version| [version.number, version.kind] }

    test 'a swap is a new version at once; the PDF as received stays version 1' do
      in_store do
        row = invoice
        post :replace, params: { id: row.batch_id, file: upload('fixed', 2) }

        assert_redirected_to aim_invoice_path(row.batch_id, queue: 'needs_review')
        assert_equal ['fixed page 1', 'fixed page 2'], texts(row.pdf_path)
        assert_equal [[1, 'received'], [2, 'swap']], versions(row)
        assert_equal ['orig page 1', 'orig page 2', 'orig page 3'], texts(Aim::PdfVersions.all(row).first.base_path)
        row.reload
        assert_equal [2, 'needs_review'], [row.page_count, row.state]
        assert_match(/PDF swapped for fixed.pdf; version 2/, row.events.last.note)
      end
    end

    test 'an edit saves its plan, so text boxes and removed pages come back to the editor' do
      in_store do
        row = invoice
        box = { x: 0.1, y: 0.1, w: 0.3, h: 0.05, size: 12, text: 'PAID', bold: false, color: 'black', bg: 'none', border: false }
        pages = [{ source: 0, page: 3, rotate: 90 }, { source: 1, page: 1, texts: [box] }, { source: 0, page: 1 }]
        patch :update, params: { id: row.batch_id, pages: pages.to_json, inserts: [upload('extra', 1)] }

        assert_equal 'PDF changes applied.', flash[:notice]
        assert_equal ['extra page 1 PAID', 'orig page 1'], texts(row.pdf_path).drop(1)
        version = Aim::PdfVersions.current(row)
        assert_equal [[1, 'received'], [2, 'edit']], versions(row)
        assert_equal 'PAID', version.plan_pages[1]['texts'].first['text']
        assert_equal ["#{row.batch_id}.insert-2-1.pdf"], version.insert_files
        note = row.reload.events.last.note
        ['removed page 2', 'added 1 page from extra.pdf', 'rotated page 3', 'text added to 1 added page', 'version 2'].each do |part|
          assert_includes note, part
        end

        data = @controller.helpers.aim_pdf_editor_data(row)
        assert_equal pages.to_json, data[:aim_pdf_editor_plan_value]
        assert_equal [aim_pdf_source_invoice_path(row.batch_id, insert: 1)], JSON.parse(data[:aim_pdf_editor_insert_urls_value])

        get :source, params: { id: row.batch_id }
        assert_equal(['orig page 1', 'orig page 2', 'orig page 3'], PDF::Reader.new(StringIO.new(response.body)).pages.map { |page| page.text.squish })
        get :source, params: { id: row.batch_id, insert: 1 }
        assert_match(/extra page 1/, PDF::Reader.new(StringIO.new(response.body)).pages.first.text)
      end
    end

    test 'a second edit says only what changed since the first' do
      in_store do
        row = invoice
        patch :update, params: { id: row.batch_id, pages: [{ source: 0, page: 1, rotate: 90 }, { source: 0, page: 2 }].to_json }
        box = { x: 0.1, y: 0.1, w: 0.3, h: 0.05, size: 12, text: 'Check 1001' }
        patch :update, params: { id: row.batch_id, pages: [{ source: 0, page: 1, rotate: 90 }, { source: 0, page: 2, texts: [box] }].to_json }

        assert_equal 'PDF edited: text changed on page 2; version 3', row.events.last.note
      end
    end

    test 'any version can be looked at, and restored as a new version' do
      in_store do
        row = invoice
        post :replace, params: { id: row.batch_id, file: upload('fixed', 1) }

        get :version, params: { id: row.batch_id, number: 1 }
        assert_equal 'application/pdf', response.media_type
        assert_equal 3, PDF::Reader.new(StringIO.new(response.body)).page_count

        post :restore, params: { id: row.batch_id, number: 1 }
        assert_equal 'Version 1 restored, as a new version.', flash[:notice]
        assert_equal [[1, 'received'], [2, 'swap'], [3, 'restore']], versions(row)
        assert_equal ['orig page 1', 'orig page 2', 'orig page 3'], texts(row.pdf_path)
        assert_equal 3, row.reload.page_count
      end
    end

    test '#181 copies are carried in as the first versions, the PDF as it is after them' do
      in_store do
        row = invoice
        write_pdf(File.join(row.store_dir, "#{row.batch_id}.v1.pdf"), 'first', 1)
        write_pdf(File.join(row.store_dir, "#{row.batch_id}.v2.pdf"), 'second', 1)
        post :replace, params: { id: row.batch_id, file: upload('fixed', 1) }

        assert_equal [[1, 'received'], [2, 'edit'], [3, 'edit'], [4, 'swap']], versions(row)
        assert_equal([['first page 1'], ['second page 1'], ['orig page 1', 'orig page 2', 'orig page 3']],
                     Aim::PdfVersions.all(row).first(3).map { |version| texts(version.base_path) })
        assert_empty Dir.children(row.store_dir).grep(/\.v\d+\.pdf\z/), 'no #181 copies left behind'
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
        assert_equal [[1, 'received']], versions(row), 'only the PDF as it was, kept'
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

    def refused?(row)
      get :source, params: { id: row.batch_id }
      response.redirect? && flash[:alert] == 'This invoice\'s PDF cannot be changed here.'
    end

    test 'once Fiscal archives it, or while the AI has it, or once rejected, it cannot be changed' do
      in_store do
        row = invoice(state: 'approved')
        record = Aim::FiscalRecord.create!(invoice: row)
        assert_not refused?(row)
        record.update_columns(status: 'archived', archived_at: Time.current)
        assert refused?(row), 'archived by Fiscal'

        record.destroy!
        %w[received extracting exporting rejected deleted split].each do |state|
          row.update_columns(state: state)
          assert refused?(row), state
        end
      end
    end

    test 'someone else in the invoice, or no AIM role, cannot change it' do
      in_store do
        row = invoice
        row.claim!('other@example.com', name: 'Other')
        assert refused?(row), 'someone else is in it'

        row.release_claim!
        assert_not refused?(row)
        assert_equal 'application/pdf', response.media_type, 'the editor reads the PDF as received'

        @controller.define_singleton_method(:current_user_group_names) { Set[] }
        assert refused?(row), 'no AIM role'
      end
    end
  end

  # The editor sits in the review page's Document Preview.
  class PdfEditorOnReviewPageTest < ActionController::TestCase
    tests Aim::InvoicesController

    test 'Edit PDF opens the editor in place; it is not offered when the PDF cannot change' do
      session[:user] = { 'email' => 'aim.staff@example.com', 'employee_id' => 42 }
      @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
      row = Aim::Invoice.create!(batch_id: '4641.R-[AB12]', state: 'needs_review', actor: 'aim_worker', budget_unit: '4641')

      get :show, params: { id: row.batch_id, queue: 'needs_review' }
      assert_select 'section.aim-document-panel[data-controller=aim-pdf-editor][data-aim-pdf-editor-pdf-url-value=?]',
                    aim_pdf_source_invoice_path(row.batch_id) do
        assert_select 'button[data-action=?]', 'aim-pdf-editor#open', text: 'Edit PDF'
        assert_select '.aim-pdf-workspace[hidden] .aim-pdf-tools button[data-action=?]', 'aim-pdf-editor#turnLeft'
        # Versions, More, Cancel and Apply sit in the panel's header, shown with the editor (#192).
        assert_select '.aim-panel-header .aim-pdf-toolbar__finish[hidden] form[action=?]', aim_edit_pdf_invoice_path(row.batch_id)
        assert_select '.aim-pdf-toolbar__finish .aim-pdf-more form[action=?] input[type=file][name=file]', aim_replace_pdf_invoice_path(row.batch_id)
        assert_select '.aim-pdf-split-mark', 0, 'the split mark is for an invoice waiting to be split'
      end

      Aim::PdfVersion.create!(invoice: row, number: 1, kind: 'received', base_file: 'a.pdf', created_by: 'aim', note: 'as received')
      Aim::PdfVersion.create!(invoice: row, number: 2, kind: 'edit', base_file: 'a.pdf', created_by: 'joshua@example.com', note: 'PDF edited: text added to page 1')
      get :show, params: { id: row.batch_id, queue: 'needs_review' }
      assert_select '.aim-pdf-versions summary', text: /Versions \(2\)/
      assert_select '.aim-pdf-versions__row', count: 2
      assert_select '.aim-pdf-versions__row:first-child', text: /v2 .* joshua .* text added to page 1 \(current\)/
      assert_select '.aim-pdf-versions__row a[href=?]', aim_pdf_version_invoice_path(row.batch_id, 1), text: 'View'
      assert_select '.aim-pdf-versions__row form[action=?]', aim_restore_pdf_version_invoice_path(row.batch_id, 1)
      assert_select '.aim-pdf-versions__row form[action=?]', aim_restore_pdf_version_invoice_path(row.batch_id, 2), count: 0

      row.update_columns(state: 'rejected')
      get :show, params: { id: row.batch_id, queue: 'rejected' }
      assert_select '[data-controller=aim-pdf-editor]', count: 0
      assert_select 'button', text: 'Edit PDF', count: 0
    end
  end

  # Edit PDF on an invoice waiting to be split (#192): "New invoice starts
  # here" marks, carried through Apply to the split screen.
  class PdfEditsSplitTest < PdfEditsTestCase
    test 'marks set in the editor reach the split screen, numbered as the edited PDF the splitter cuts (#192)' do
      in_store do
        row = invoice(state: 'needs_split', pages: 4)
        row.update!(manifest: { 'bu' => '4641', 'invoices' => [{ 'vendor_name' => 'ACME', 'invoice_number' => 'N-1', 'pages' => [1, 2, 3, 4] }] }.to_json)
        # Page 2 removed; invoices start on the PDF's new pages 1 and 2.
        pages = [{ source: 0, page: 1 }, { source: 0, page: 3 }, { source: 0, page: 4 }]
        patch :update, params: { id: row.batch_id, pages: pages.to_json, split_starts: [2].to_json }

        row.reload
        assert_equal ['orig page 1', 'orig page 3', 'orig page 4'], texts(row.pdf_path), 'what the splitter cuts'
        assert_equal [[1], [2, 3]], row.manifest_data['invoices'].pluck('pages')
        assert_equal %w[ACME N-1], row.manifest_data['invoices'].first.values_at('vendor_name', 'invoice_number')
        assert_equal %w[needs_split 4641], [row.state, row.manifest_data['bu']]
      end
    end

    test 'marks mean nothing on an invoice that is not waiting to be split' do
      in_store do
        row = invoice
        patch :update, params: { id: row.batch_id, pages: [{ source: 0, page: 1 }].to_json, split_starts: [2].to_json }

        assert_empty row.reload.manifest_data
      end
    end
  end
end
