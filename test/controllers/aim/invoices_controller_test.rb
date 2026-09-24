# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
require 'prawn'

module Aim
  # The queues and the review page over rows. Every button is a move of the
  # row's state; a move the pipeline does not make is refused with a message;
  # the PDF is read from the store and never moved. AIM v2.
  # rubocop:disable-next Metrics/ClassLength
  class InvoicesControllerTest < ActionController::TestCase
    tests Aim::InvoicesController

    FOLDERS = {
      'AIM_BASE_DIR' => 'Invoices',
      'AIM_STORE_DIR' => '_BACK_END\\_STORE',
      'AIM_DELETED_DIR' => 'Invoices\\_GONE',
      'AIM_REJECTED_DIR' => '_BACK_END\\_SENT_BACK'
    }.freeze
    AIM_ENV = (%w[AIM_WINDOWS_QUEUE_BASE_PATH AIM_LINUX_QUEUE_BASE_PATH] + FOLDERS.keys).freeze
    REVIEWER = 'aim.staff@example.com'

    setup do
      @tmpdir = Dir.mktmpdir
      @old_env = AIM_ENV.to_h { |key| [key, ENV.fetch(key, nil)] }
      ENV['AIM_WINDOWS_QUEUE_BASE_PATH'] = 'E:\AIM'
      ENV['AIM_LINUX_QUEUE_BASE_PATH'] = @tmpdir
      FOLDERS.each { |variable, folder| ENV[variable] = "E:\\AIM\\#{folder}" }
      FileUtils.mkdir_p(File.join(@tmpdir, '_BACK_END', '_STORE'))

      session[:user] = { 'email' => REVIEWER, 'employee_id' => 42, 'first_name' => 'Aim', 'last_name' => 'Staff' }
      @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    end

    teardown do
      @old_env.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
      FileUtils.remove_entry(@tmpdir) if @tmpdir && Dir.exist?(@tmpdir)
    end

    def invoice(batch_id, state: 'needs_review', pdf: true, pages: 1, **attributes)
      if pdf
        folder = File.join(@tmpdir, '_BACK_END', '_STORE', batch_id)
        FileUtils.mkdir_p(folder)
        Prawn::Document.generate(File.join(folder, "#{batch_id}.pdf")) do |doc|
          pages.times { |index| doc.start_new_page unless index.zero? }
        end
      end
      defaults = { document_type: 'Invoice', vendor_name: 'ACME', invoice_number: 'INV-1', budget_unit: '4601',
                   submitter: 'Jane Doe', page_count: pages }
      Aim::Invoice.create!(batch_id: batch_id, state: state, actor: 'aim_worker', **defaults.merge(attributes))
    end

    def act(row, commit, queue: row.queue, **params)
      patch :update, params: { id: row.batch_id, queue: queue, commit: commit, **params }
      row.reload
    end

    # ---------------------------------------------------------------
    # Queues
    # ---------------------------------------------------------------

    test 'a queue lists the rows in its states, newest first' do
      older = invoice('4601.A', state: 'approved', pdf: false)
      newer = invoice('4601.B', state: 'exporting', pdf: false)
      invoice('4601.C', state: 'needs_review', pdf: false)

      get :index, params: { queue: 'in_flight' }

      assert_response :success
      assert_equal [newer.batch_id, older.batch_id], @controller.instance_variable_get(:@invoices).map(&:batch_id)
    end

    test 'needs review can be filtered by reason' do
      invoice('4601.D', review_reason: 'unknown_vendor', pdf: false)
      invoice('4601.E', review_reason: 'handwritten', pdf: false)

      get :index, params: { queue: 'needs_review', review_reason: 'handwritten' }

      assert_equal ['4601.E'], @controller.instance_variable_get(:@invoices).map(&:batch_id)
      assert_equal({ 'unknown_vendor' => 1, 'handwritten' => 1 }, @controller.instance_variable_get(:@reason_counts))
    end

    test 'an unknown queue goes home' do
      get :index, params: { queue: 'sql_queue' }

      assert_redirected_to aim_root_path
    end

    # ---------------------------------------------------------------
    # The review page
    # ---------------------------------------------------------------

    test 'opening an invoice claims it on the row, by name' do
      row = invoice('4601.F')

      get :show, params: { id: row.batch_id, queue: 'needs_review' }

      assert_response :success
      assert_equal [REVIEWER, 'Aim Staff'], [row.reload.claimed_by, row.claimed_by_name]
      assert_select 'input[type=submit][value=?]', 'Send to Approval'
      assert_select 'input[type=submit][value=?][data-turbo-confirm]', 'Delete'
    end

    test 'an invoice someone else holds is read only' do
      row = invoice('4601.G', claimed_by: 'other@example.com', claimed_at: Time.current, claimed_by_name: 'Dana Reyes')

      get :show, params: { id: row.batch_id, queue: 'needs_review' }

      assert_response :success
      assert_includes response.body, 'Dana Reyes claimed this invoice'
      assert_select 'input[type=submit][value=?]', 'Send to Approval', count: 0

      patch :update, params: { id: row.batch_id, queue: 'needs_review', commit: 'Save Changes' }
      assert_redirected_to aim_invoices_path(queue: 'needs_review')
      assert_match(/view only/, flash[:alert])
    end

    test 'a finished invoice is shown, not claimed' do
      row = invoice('4601.H', state: 'exported', pdf: false)

      get :show, params: { id: row.batch_id, queue: 'exported' }

      assert_response :success
      assert_nil row.reload.claimed_by
    end

    test 'the pdf is served from the store' do
      row = invoice('4601.I')

      get :pdf, params: { id: row.batch_id, queue: 'needs_review' }

      assert_response :success
      assert_equal 'application/pdf', response.media_type
    end

    test 'a missing pdf is not found' do
      row = invoice('4601.J', pdf: false)

      get :pdf, params: { id: row.batch_id, queue: 'needs_review' }

      assert_response :not_found
    end

    test 'an unknown invoice goes back to the queue' do
      get :show, params: { id: 'nope', queue: 'needs_review' }

      assert_redirected_to aim_invoices_path(queue: 'needs_review')
    end

    # ---------------------------------------------------------------
    # Actions
    # ---------------------------------------------------------------

    test 'save writes the reviewed fields and notes to the row' do
      row = invoice('4601.K', pdf: false)

      act(row, 'Save Changes', invoice: { vendor_name: ' AT&T MOBILITY ', invoice_total: '1234.50',
                                          invoice_date: '2026-06-22', notes: 'checked', document_type: 'Credit' })

      assert_equal 'AT&T MOBILITY', row.vendor_name
      assert_equal BigDecimal('1234.50'), row.invoice_total
      assert_equal Date.new(2026, 6, 22), row.invoice_date
      assert_equal %w[checked Credit], [row.notes, row.document_type]
      assert_equal 'needs_review', row.state
    end

    test 'send to approval moves the row and releases the claim' do
      row = invoice('4601.L', review_reason: 'missing_fields', claimed_by: REVIEWER, claimed_at: Time.current)

      act(row, 'Send to Approval')

      assert_equal 'ready_for_approval', row.state
      assert_nil row.review_reason
      assert_nil row.claimed_by
      assert_equal REVIEWER, row.events.last.actor
    end

    test 'an invoice missing its vendor is not sent for approval, and nothing moves' do
      row = invoice('4601.M', vendor_name: nil, pdf: false)

      act(row, 'Send to Approval')

      assert_equal 'needs_review', row.state
      assert_match(/still needs a vendor name/, flash[:alert])
    end

    test 'approve asks the worker to export' do
      row = invoice('4601.N', state: 'ready_for_approval', pdf: false)

      act(row, 'Approve')

      assert_equal %w[approved export], [row.state, row.command]
    end

    test 'send back returns an invoice to AIM review' do
      row = invoice('4601.O', state: 'ready_for_approval', pdf: false)

      act(row, 'Send Back', note: 'wrong PO')

      assert_equal 'needs_review', row.state
      assert_equal 'wrong PO', row.events.last.note
    end

    test 'retry ai asks the worker to extract again' do
      row = invoice('4601.P', state: 'failed', review_reason: 'extraction_error', pdf: false)

      act(row, 'Retry AI')

      assert_equal %w[received extract], [row.state, row.command]
      assert_nil row.review_reason
    end

    test 'retry export asks the worker to export again' do
      row = invoice('4601.Q', state: 'failed', pdf: false)

      act(row, 'Retry Export')

      assert_equal %w[approved export], [row.state, row.command]
    end

    test 'a move the pipeline does not make is refused with its reason' do
      row = invoice('4601.R', state: 'ready_for_approval', pdf: false)

      act(row, 'Retry AI')

      assert_equal 'ready_for_approval', row.state
      assert_redirected_to aim_invoice_path(row.batch_id, queue: 'ready_for_approval')
      assert_match(/cannot move from ready_for_approval to received/, flash[:alert])
    end

    test 'reject keeps a copy for the submitter and ends the invoice' do
      row = invoice('4601.S')

      act(row, 'Reject')

      assert_equal 'rejected', row.state
      assert File.exist?(File.join(@tmpdir, '_BACK_END', '_SENT_BACK', 'Jane Doe_4601', '4601.S.pdf'))
      assert File.exist?(row.pdf_path), 'the store keeps its copy'
    end

    test 'delete keeps a copy and ends the invoice' do
      row = invoice('4601.T')

      act(row, 'Delete')

      assert_equal 'deleted', row.state
      assert File.exist?(File.join(@tmpdir, 'Invoices', '_GONE', '4601.T', '4601.T.pdf'))
    end

    test 'learning an alias records it and sets the vendor before the next step' do
      row = invoice('4601.U', review_reason: 'unknown_vendor', vendor_name: nil, extracted_vendor_name: 'AIRGAS USA LLC', pdf: false)

      act(row, 'Learn & Send to Approval', normalized_vendor_new: 'Airgas')

      assert_equal 'Airgas', row.vendor_name
      assert_equal 'ready_for_approval', row.state
      assert_equal 'Airgas', Aim::VendorAlias.find_by(extracted_name: 'AIRGAS USA LLC').normalized_name
    end

    test 'unclaim releases the row' do
      row = invoice('4601.V', claimed_by: REVIEWER, claimed_at: Time.current, pdf: false)

      act(row, 'Unclaim')

      assert_nil row.claimed_by
    end

    # ---------------------------------------------------------------
    # Splits
    # ---------------------------------------------------------------

    def split_params(*rows)
      rows.each_with_index.to_h do |(vendor, number, pages), index|
        [index.to_s, { vendor_name: vendor, invoice_number: number, pages_text: pages }]
      end
    end

    test 'the split page shows the proposed invoices' do
      row = invoice('4601.W', state: 'needs_split', pages: 3,
                              manifest: { 'invoices' => [{ 'vendor_name' => 'ACME', 'invoice_number' => 'INV-1', 'pages' => [1, 2] },
                                                         { 'vendor_name' => 'ACME', 'invoice_number' => 'INV-2', 'pages' => [3] }] }.to_json)

      get :show, params: { id: row.batch_id, queue: 'needs_split' }

      assert_response :success
      assert_select 'input[name=?][value=?]', 'split[0][pages_text]', '1-2'
      assert_select 'input[type=submit][value=?]', 'Approve Split'
    end

    test 'an approved split saves the manifest and asks the worker to cut' do
      row = invoice('4601.X', state: 'needs_split', pages: 3, manifest: { 'bu' => '4601', 'invoices' => [] }.to_json)

      act(row, 'Approve Split', split: split_params(%w[ACME INV-1 1], %w[ACME INV-2 2-3]))

      assert_equal %w[needs_split split], [row.state, row.command]
      assert_equal [[1], [2, 3]], row.manifest_data['invoices'].pluck('pages')
      assert_equal '4601', row.manifest_data['bu']
    end

    test 'a split that does not make sense is refused, keeping what was typed' do
      row = invoice('4601.Y', state: 'needs_split', pages: 3)

      act(row, 'Approve Split', split: split_params(%w[ACME INV-1 1-2], %w[ACME INV-2 2-3]))

      assert_response :unprocessable_content
      assert_includes response.body, 'Page 2 is in invoices 1 and 2'
      assert_nil row.command
    end

    test 'process as one invoice sends it back through extraction unsplit' do
      row = invoice('4601.Z', state: 'needs_split', pdf: false)

      act(row, 'Process as One Invoice')

      assert_equal %w[received extract], [row.state, row.command]
      assert_not row.split_check
    end

    # ---------------------------------------------------------------
    # People's queues
    # ---------------------------------------------------------------

    test 'ready for approval is grouped by person, one shared queue per BU last, collapsed' do
      invoice('4601.O1', state: 'ready_for_approval', pdf: false, assigned_to: 'Jane Doe', assigned_employee_id: 7,
                         assignment_source: 'folder')
      invoice('4601.O2', state: 'ready_for_approval', pdf: false, assigned_to: 'Jane Doe', assigned_employee_id: 7,
                         assignment_source: 'folder')
      invoice('4601.O3', state: 'ready_for_approval', pdf: false)

      get :index, params: { queue: 'ready_for_approval' }

      assert_response :success
      assert_equal(['Jane Doe', '4601 shared queue'], @controller.instance_variable_get(:@groups).map { |key, _| key.last })
      assert_select 'section.aim-owner-group', 2
      assert_select 'section.aim-owner-group button[aria-expanded=false]', 2, 'the groups start collapsed'
      assert_select 'section.aim-owner-group .aim-count-pill', text: '2 invoices'
      assert_select 'button.aim-move-button', 3
      assert_select '[data-controller=aim-person-search] input[type=hidden][name=owner]'
    end

    test 'moving an invoice to a person records it and returns to the queue' do
      employee = Employee.order(:id).first || skip('no employee to test with')
      row = invoice('4601.O5', state: 'ready_for_approval', pdf: false)

      patch :reassign, params: { id: row.batch_id, queue: 'ready_for_approval', destination: 'person', owner: employee.id }

      assert_redirected_to aim_invoices_path(queue: 'ready_for_approval')
      assert_equal employee.id, row.reload.assigned_employee_id
      assert_equal REVIEWER, row.events.last.actor
    end

    test 'moving an invoice to the shared queue clears its owner' do
      row = invoice('4601.O7', state: 'ready_for_approval', pdf: false, assigned_to: 'Jane Doe', assigned_employee_id: 7,
                               assignment_source: 'folder')

      patch :reassign, params: { id: row.batch_id, queue: 'ready_for_approval', destination: 'shared', owner: '' }

      assert_nil row.reload.assigned_employee_id
    end

    test 'a finished invoice is not moved' do
      row = invoice('4601.O6', state: 'exported', pdf: false)

      patch :reassign, params: { id: row.batch_id, queue: 'exported', owner: 'Sam Lee' }

      assert_match(/finished/, flash[:alert])
      assert_nil row.reload.assigned_to
    end
  end
end
