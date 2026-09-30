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
    include ActiveJob::TestHelper

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
                   invoice_date: Date.new(2026, 9, 1), invoice_total: 10, submitter: 'Jane Doe', page_count: pages }
      Aim::Invoice.create!(batch_id: batch_id, state: state, actor: 'aim_worker', **defaults.merge(attributes))
    end

    def act(row, action, queue: row.queue, **params)
      patch :update, params: { id: row.batch_id, queue: queue, invoice_action: action, **params }
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

    test 'needs review carries every row with its reason, and the reason buttons filter on the page' do
      invoice('4601.D', review_reason: 'unknown_vendor', pdf: false)
      invoice('4601.E', review_reason: 'handwritten', pdf: false)

      get :index, params: { queue: 'needs_review' }

      assert_equal %w[4601.E 4601.D], @controller.instance_variable_get(:@invoices).map(&:batch_id)
      assert_equal({ 'unknown_vendor' => 1, 'handwritten' => 1 }, @controller.instance_variable_get(:@reason_counts))
      assert_select 'button[data-reason=handwritten][data-action*=pickReason]'
      assert_select 'tr[data-reason=handwritten]', 1
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
      assert_select 'button[name=invoice_action][value=?]', 'send_to_approval'
      assert_select 'button[data-action=?][data-value=?][data-commit=?]', 'aim-reason#open', 'delete', 'Delete'
      assert_select '.pb-modal button[type=submit][name=invoice_action][data-aim-reason-target=submit]'
    end

    test 'Return to Queue goes back to the queue page the invoice was opened from' do
      row = invoice('4601.R')
      session[:aim_queue_page] = '/aim/admin/users/300'

      get :show, params: { id: row.batch_id }

      assert_select 'a[href=?]', '/aim/admin/users/300', text: 'Back to Queue'
    end

    test 'an invoice someone else holds is read only' do
      row = invoice('4601.G', claimed_by: 'other@example.com', claimed_at: Time.current, claimed_by_name: 'Dana Reyes')

      get :show, params: { id: row.batch_id, queue: 'needs_review' }

      assert_response :success
      assert_includes response.body, 'Dana Reyes is working on this invoice. You can view it'
      assert_select 'button[name=invoice_action][value=?]', 'send_to_approval', count: 0
      assert_select '[data-controller~=aim-presence]', 0, 'a reader keeps no lock'

      patch :update, params: { id: row.batch_id, queue: 'needs_review', invoice_action: 'save' }
      assert_redirected_to aim_invoice_path(row.batch_id, queue: 'needs_review')
      assert_match(/is working on this invoice/, flash[:alert])
    end

    test 'a lock whose page stopped checking in has lapsed' do
      row = invoice('4601.G2', claimed_by: 'other@example.com', claimed_at: 5.minutes.ago, claimed_by_name: 'Dana Reyes')

      get :show, params: { id: row.batch_id, queue: 'needs_review' }

      assert_equal REVIEWER, row.reload.claimed_by, 'the stale lock gives way'
      assert_select '[data-controller~=aim-presence]'
    end

    test "staff looking at someone else's ready invoice read it, lock nothing, and may claim it" do
      employee = Employee.order(:id).first || skip('no employee to test with')
      session[:user] = session[:user].merge('employee_id' => employee.id)
      row = invoice('4601.K1', state: 'ready_for_approval', assigned_to: 'Sam Lee', assigned_employee_id: employee.id + 1,
                               assignment_source: 'folder')

      get :show, params: { id: row.batch_id, queue: 'ready_for_approval' }

      assert_nil row.reload.claimed_by, 'looking never locks'
      assert_select 'button[name=invoice_action][value=approve]', 0
      assert_select 'form[action=?]', claim_aim_invoice_path(row.batch_id, queue: 'ready_for_approval')

      Aim::Users.stub(:member?, true) { post :claim, params: { id: row.batch_id, queue: 'ready_for_approval' } }
      assert_equal employee.id, row.reload.assigned_employee_id, 'Claim moves it to your queue'
    end

    test 'the page checks in to keep its lock, and lets go when left' do
      row = invoice('4601.K2')
      row.claim!(REVIEWER, name: 'Aim Staff')
      row.update_columns(claimed_at: 60.seconds.ago)

      patch :lock, params: { id: row.batch_id, queue: 'needs_review' }
      assert_response :no_content
      assert_operator row.reload.claimed_at, :>, 5.seconds.ago

      post :unlock, params: { id: row.batch_id, queue: 'needs_review' }
      assert_nil row.reload.claimed_by
    end

    test 'checking in on an invoice someone else is working is refused' do
      row = invoice('4601.K3', claimed_by: 'other@example.com', claimed_at: Time.current, claimed_by_name: 'Dana Reyes')

      patch :lock, params: { id: row.batch_id, queue: 'needs_review' }

      assert_response :conflict
      assert_equal 'other@example.com', row.reload.claimed_by
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

      act(row, 'save', invoice: { vendor_name: ' AT&T MOBILITY ', invoice_total: '1234.50',
                                  invoice_date: '2026-06-22', notes: 'checked', document_type: 'Credit' })

      assert_equal 'AT&T MOBILITY', row.vendor_name
      assert_equal BigDecimal('1234.50'), row.invoice_total
      assert_equal Date.new(2026, 6, 22), row.invoice_date
      assert_equal %w[checked Credit], [row.notes, row.document_type]
      assert_equal 'needs_review', row.state
    end

    test 'send to approval moves the row and releases the claim' do
      row = invoice('4601.L', review_reason: 'missing_fields', claimed_by: REVIEWER, claimed_at: Time.current)

      act(row, 'send_to_approval')

      assert_equal 'ready_for_approval', row.state
      assert_nil row.review_reason
      assert_nil row.claimed_by
      assert_equal REVIEWER, row.events.where(action: 'transition').last.actor
      assert row.coded?, 'sending to approval codes the invoice'
    end

    test 'several matching coding rules are offered on the review page, and one can be picked' do
      %w[BDO_46002024072600000001_1 BDO_46002024072600000001_2].each do |enc|
        Aim::CodingRule.create!(agency: 'GSA', budget_unit: '4601', vendor_name: 'ACME', encumbrance: enc,
                                object_code: '2162', effective_from: Date.new(2024, 7, 1))
      end
      row = invoice('4601.C1', state: 'ready_for_approval', pdf: false)

      get :show, params: { id: row.batch_id, queue: 'ready_for_approval' }
      assert_response :success
      assert_select 'input[type=radio][name=coding_rule_id]', 2
      assert_select 'select[name=?]', 'coding_line[object_code]'
      assert_select 'input[type=radio][data-rule]', 2
      assert row.reload.coded?
      assert_empty row.coding_lines

      act(row, 'approve', queue: 'ready_for_approval')
      assert_equal 'ready_for_approval', row.state
      assert_match(/Pick or enter the coding/, flash[:alert])

      picked = Aim::CodingRule.last
      act(row, 'save', queue: 'ready_for_approval',
                       coding_line: { encumbrance: picked.encumbrance, object_code: '2162', coding_rule_id: picked.id })

      line = row.coding_lines.first
      assert_equal ['BDO_46002024072600000001_2', 'person', REVIEWER, picked.id], [line.encumbrance, line.source, line.set_by, line.coding_rule_id]
      assert_match(/set .*rule picked/, row.events.last.note)
    end

    test 'look up coding again replaces the coding from the rules, and an invoice missing its date or total is not sent on' do
      Aim::CodingRule.create!(agency: 'GSA', budget_unit: '4601', vendor_name: 'ACME', encumbrance: 'BDO_46002024072600000001_1',
                              object_code: '2162', effective_from: Date.new(2024, 7, 1))
      row = invoice('4601.C3', state: 'ready_for_approval', pdf: false)
      row.coding_lines.create!(object_code: '9999', source: 'person', set_by: 'someone')

      get :show, params: { id: row.batch_id, queue: 'ready_for_approval' }
      post :relookup, params: { id: row.batch_id, queue: 'ready_for_approval' }
      assert_response :success
      assert_select 'section.aim-coding'
      assert_match(/coded from the matching rule/, response.body)
      assert_equal %w[2162 rule], [row.reload.coding.object_code, row.coding.source]

      bare = invoice('4601.C4', invoice_date: nil, invoice_total: nil)
      act(bare, 'send_to_approval')
      assert_equal 'needs_review', bare.state
      assert_match(/still needs an invoice date and an invoice total/, flash[:alert])
    end

    test 'save changes redraws only the form panel; the other buttons leave it' do
      row = invoice('4601.F1', state: 'ready_for_approval', pdf: false)
      get :show, params: { id: row.batch_id, queue: 'ready_for_approval' }

      assert_select 'turbo-frame#aim-review-panel[target=_top]' do
        assert_select 'button[name=invoice_action][value=?][data-turbo-frame=?]', 'save', 'aim-review-panel'
        assert_select 'button[name=invoice_action][value=approve]:not([data-turbo-frame])'
      end
    end

    test 'a reviewer enters the coding by hand when no rule fits' do
      row = invoice('4601.C2', state: 'ready_for_approval', pdf: false)

      act(row, 'save', queue: 'ready_for_approval',
                       coding_line: { encumbrance: 'DO_46012026', object_code: '2162', activity: 'GATV' })

      line = row.coding_lines.first
      assert_equal %w[DO_46012026 2162 GATV person], [line.encumbrance, line.object_code, line.activity, line.source]
      assert_match(/set .*Object/, row.events.last.note)
    end

    test 'an invoice missing its vendor is not sent for approval, and nothing moves' do
      row = invoice('4601.M', vendor_name: nil, pdf: false)

      act(row, 'send_to_approval')

      assert_equal 'needs_review', row.state
      assert_match(/still needs a vendor name/, flash[:alert])
    end

    test 'approve asks the worker to export, and queues the approval stamp' do
      row = invoice('4601.N', state: 'ready_for_approval', pdf: false)

      assert_enqueued_with(job: Aim::StampApprovedJob, args: [row.id]) { act(row, 'approve') }

      assert_equal %w[approved export], [row.state, row.command]
    end

    test 'approve is refused outside a user queue; send to approval is the way there' do
      row = invoice('4601.N2', state: 'needs_review', pdf: false)

      get :show, params: { id: row.batch_id, queue: 'needs_review' }
      assert_select 'button[name=invoice_action][value=approve]', 0

      act(row, 'approve')
      assert_equal 'needs_review', row.state
      assert_match(/from its queue/, flash[:alert])
    end

    test 'delete is refused to anyone but an AIM admin, on the server too' do
      row = invoice('4601.N3', state: 'ready_for_approval', assigned_to: 'Jane Doe', assigned_employee_id: 7,
                               assignment_source: 'folder')
      as_owner_not_staff
      get :show, params: { id: row.batch_id, queue: 'ready_for_approval' }

      act(row, 'delete', reason: 'no', queue: 'ready_for_approval')
      assert_equal 'ready_for_approval', row.state
      assert_match(/Only AIM Admins|not in your queue/, flash[:alert])
    end

    test 'send back returns an invoice to AIM review' do
      row = invoice('4601.O', state: 'ready_for_approval', pdf: false)

      act(row, 'send_back', reason: 'wrong PO')

      assert_equal 'needs_review', row.state
      assert_equal 'reason: wrong PO', row.events.last.note
      assert_match(/Sent back by Aim Staff: wrong PO\z/, row.notes)
    end

    test 'reject, delete and send back need a reason, and nothing moves without one' do
      row = invoice('4601.O9', state: 'ready_for_approval', pdf: false)

      act(row, 'reject', reason: '  ')

      assert_equal 'ready_for_approval', row.state
      assert_match(/needs a reason/, flash[:alert])
    end

    test 'the reason is added to what the notes already say' do
      row = invoice('4601.O8', notes: 'Called the vendor.')

      act(row, 'reject', reason: 'duplicate of INV-1')

      assert_match(/\ACalled the vendor.\n\d{4}-\d{2}-\d{2} \d{2}:\d{2} Rejected by Aim Staff: duplicate of INV-1\z/, row.notes)
      assert_match(/\Areason: duplicate of INV-1; /, row.events.last.note)
    end

    test 'retry ai asks the worker to extract again' do
      row = invoice('4601.P', state: 'failed', review_reason: 'extraction_error', pdf: false)

      act(row, 'retry_ai')

      assert_equal %w[received extract], [row.state, row.command]
      assert_nil row.review_reason
    end

    test 'retry export asks the worker to export again' do
      row = invoice('4601.Q', state: 'failed', pdf: false)

      act(row, 'retry_export')

      assert_equal %w[approved export], [row.state, row.command]
    end

    test 'a button\'s label is no action; the stable value is' do
      row = invoice('4601.R0', state: 'ready_for_approval', pdf: false)

      patch :update, params: { id: row.batch_id, queue: 'ready_for_approval', commit: 'Approve' }

      assert_equal 'Unknown action.', flash[:alert]
      assert_equal 'ready_for_approval', row.reload.state
    end

    test 'a move the pipeline does not make is refused with its reason' do
      row = invoice('4601.R', state: 'ready_for_approval', pdf: false)

      act(row, 'retry_ai')

      assert_equal 'ready_for_approval', row.state
      assert_redirected_to aim_invoice_path(row.batch_id, queue: 'ready_for_approval')
      assert_match(/cannot move from ready_for_approval to received/, flash[:alert])
    end

    test 'reject keeps a copy for the submitter and ends the invoice' do
      row = invoice('4601.S')

      act(row, 'reject', reason: 'not ours')

      assert_equal 'rejected', row.state
      assert File.exist?(File.join(@tmpdir, '_BACK_END', '_SENT_BACK', 'Jane Doe_4601', '4601.S.pdf'))
      assert File.exist?(row.pdf_path), 'the store keeps its copy'
    end

    test 'delete keeps a copy and ends the invoice' do
      row = invoice('4601.T')

      act(row, 'delete', reason: 'test upload')

      assert_equal 'deleted', row.state
      assert File.exist?(File.join(@tmpdir, 'Invoices', '_GONE', '4601.T', '4601.T.pdf'))
    end

    test 'learning an alias records it and sets the vendor before the next step' do
      row = invoice('4601.U', review_reason: 'unknown_vendor', vendor_name: nil, extracted_vendor_name: 'AIRGAS USA LLC', pdf: false)

      act(row, 'learn_and_send', normalized_vendor_new: 'Airgas')

      assert_equal 'Airgas', row.vendor_name
      assert_equal 'ready_for_approval', row.state
      assert_equal 'Airgas', Aim::VendorAlias.find_by(extracted_name: 'AIRGAS USA LLC').normalized_name
    end

    test 'unclaim releases the row' do
      row = invoice('4601.V', claimed_by: REVIEWER, claimed_at: Time.current, pdf: false)

      act(row, 'unclaim')

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

      get :show, params: { id: row.batch_id, queue: 'needs_review' }

      assert_response :success
      assert_select 'input[name=?][value=?]', 'split[0][pages_text]', '1-2'
      assert_select 'button[name=invoice_action][value=?]', 'approve_split'
    end

    test 'an approved split saves the manifest and asks the worker to cut' do
      row = invoice('4601.X', state: 'needs_split', pages: 3, manifest: { 'bu' => '4601', 'invoices' => [] }.to_json)

      act(row, 'approve_split', split: split_params(%w[ACME INV-1 1], %w[ACME INV-2 2-3]))

      assert_equal %w[needs_split split], [row.state, row.command]
      assert_equal [[1], [2, 3]], row.manifest_data['invoices'].pluck('pages')
      assert_equal '4601', row.manifest_data['bu']
    end

    test 'a split that does not make sense is refused, keeping what was typed' do
      row = invoice('4601.Y', state: 'needs_split', pages: 3)

      act(row, 'approve_split', split: split_params(%w[ACME INV-1 1-2], %w[ACME INV-2 2-3]))

      assert_response :unprocessable_content
      assert_includes response.body, 'Page 2 is in invoices 1 and 2'
      assert_nil row.command
    end

    test 'process as one invoice sends it back through extraction unsplit' do
      row = invoice('4601.Z', state: 'needs_split', pdf: false)

      act(row, 'process_as_one')

      assert_equal %w[received extract], [row.state, row.command]
      assert_not row.split_check
    end

    # ---------------------------------------------------------------
    # People's queues
    # ---------------------------------------------------------------

    test 'ready for approval is grouped by BU, then its shared queue and each person, collapsed' do
      invoice('4601.O1', state: 'ready_for_approval', pdf: false, assigned_to: 'Jane Doe', assigned_employee_id: 7,
                         assignment_source: 'folder')
      invoice('4601.O2', state: 'ready_for_approval', pdf: false, assigned_to: 'Jane Doe', assigned_employee_id: 7,
                         assignment_source: 'folder')
      invoice('4601.O3', state: 'ready_for_approval', pdf: false)

      get :index, params: { queue: 'ready_for_approval' }

      assert_response :success
      sections = @controller.instance_variable_get(:@sections)
      assert_equal ['4601'], sections.map(&:unit)
      assert_equal ['Jane Doe'], sections.first.people.map(&:name)
      assert_equal 1, sections.first.shared.size
      assert_select 'section.aim-bu-group', 1
      assert_select 'section.aim-bu-group .aim-count-pill', text: '3 invoices'
      assert_select 'section.aim-bu-person', 2, 'the shared queue, then Jane Doe'
      assert_select 'section.aim-bu-person .aim-count-pill', text: '2 invoices'
      assert_select 'section.aim-bu-group > h2 button[aria-expanded=false]', 1, 'the groups start collapsed'
      assert_select '.aim-bu-person__shared', 0, 'no people tools in the Pipeline'
      assert_select 'input[type=checkbox][data-aim-move-modal-target=check]', 3
      assert_select 'button.aim-move-button', 0, 'one way to move: tick, then Move selected'
      assert_select 'select[name=owner][data-controller=aim-grouped-search]'
      assert_select 'input[type=checkbox][data-budget-unit=?]', '4601', minimum: 1
    end

    test 'moving an invoice to a person records it and returns to the queue' do
      employee = Employee.order(:id).first || skip('no employee to test with')
      row = invoice('4601.O5', state: 'ready_for_approval', pdf: false)

      Aim::Users.stub(:member?, true) do
        Aim::Users.stub(:budget_units_of, ['4601']) do
          patch :reassign, params: { id: row.batch_id, queue: 'ready_for_approval', destination: 'person', owner: employee.id }
        end
      end

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

    # ---------------------------------------------------------------
    # Owners who are not AIM staff
    # ---------------------------------------------------------------

    def as_owner_not_staff
      session[:user] = session[:user].merge('employee_id' => 7)
      @controller.define_singleton_method(:current_user_group_names) { Set[] }
      @controller.helpers.define_singleton_method(:aim_queue_access?) { false }
      @controller.helpers.define_singleton_method(:can_access_app?) { |*| true }
    end

    test 'an owner who is not staff may open and approve their own ready invoice' do
      row = invoice('4601.W1', state: 'ready_for_approval', assigned_to: 'Jane Doe', assigned_employee_id: 7,
                               assignment_source: 'folder')
      as_owner_not_staff

      get :show, params: { id: row.batch_id, queue: 'ready_for_approval' }
      assert_response :success
      assert_select 'button[data-value=delete]', 0, 'deleting is for AIM staff'

      act(row, 'approve', queue: 'ready_for_approval')
      assert_equal 'approved', row.state
      assert_redirected_to aim_my_queue_path
    end

    test "an owner cannot open someone else's invoice, or one that is not ready yet" do
      theirs = invoice('4601.W2', state: 'ready_for_approval', assigned_to: 'Sam Lee', assigned_employee_id: 8,
                                  assignment_source: 'folder')
      early = invoice('4601.W3', state: 'needs_review', assigned_to: 'Jane Doe', assigned_employee_id: 7,
                                 assignment_source: 'folder')
      as_owner_not_staff

      [theirs, early].each do |row|
        get :show, params: { id: row.batch_id, queue: row.queue }
        assert_redirected_to aim_my_queue_path
      end
    end

    test 'an owner who is not staff has only the owner actions' do
      row = invoice('4601.W4', state: 'ready_for_approval', assigned_to: 'Jane Doe', assigned_employee_id: 7,
                               assignment_source: 'folder')
      as_owner_not_staff

      act(row, 'delete', queue: 'ready_for_approval', reason: 'x')

      assert_equal 'ready_for_approval', row.state
      assert_redirected_to aim_my_queue_path
    end

    test 'the queue lists stay AIM staff only' do
      as_owner_not_staff

      get :index, params: { queue: 'ready_for_approval' }

      assert_redirected_to aim_root_path
    end

    test 'queue rows carry what the search looks through' do
      invoice('4601.S1', state: 'ready_for_approval', pdf: false, vendor_name: 'House Sanitary Supply',
                         invoice_number: 'OP-41664_FM-28844')

      get :index, params: { queue: 'ready_for_approval' }

      assert_select 'input[data-aim-queue-filter-target=input]'
      assert_select 'tr[data-aim-queue-filter-target=row][data-search*=?]', 'House Sanitary Supply OP-41664_FM-28844'
    end

    # ---------------------------------------------------------------
    # Shared queues
    # ---------------------------------------------------------------

    test 'a shared-queue invoice in a BU whose shared queue someone has switched on is theirs to work and claim' do
      employee = Employee.where.not(unit: [nil, '']).order(:id).first || skip('no employee with a unit to test with')
      row = invoice('4601.SQ1', state: 'ready_for_approval', budget_unit: employee.unit)
      other = invoice('4601.SQ2', state: 'ready_for_approval', budget_unit: employee.unit == '9999' ? '9998' : '9999')
      as_owner_not_staff
      session[:user] = session[:user].merge('employee_id' => employee.id)

      get :show, params: { id: row.batch_id, queue: 'ready_for_approval' }
      assert_redirected_to aim_my_queue_path, 'the home unit alone does not open its shared queue'

      Aim::UserBudgetUnit.create!(employee_id: employee.id, budget_unit: employee.unit, shared_queue: true)

      get :show, params: { id: row.batch_id, queue: 'ready_for_approval' }
      assert_response :success
      assert_equal REVIEWER, row.reload.claimed_by, 'working it takes the lock'

      get :show, params: { id: other.batch_id, queue: 'ready_for_approval' }
      assert_redirected_to aim_my_queue_path, "another BU's shared queue is not theirs"

      post :claim, params: { id: row.batch_id, queue: 'ready_for_approval' }
      assert_equal employee.id, row.reload.assigned_employee_id
    end

    # ---------------------------------------------------------------
    # Moving several at once
    # ---------------------------------------------------------------

    test 'ticked invoices move together, and the queue pages offer the checkboxes' do
      a = invoice('4601.B1', state: 'ready_for_approval', pdf: false, assigned_to: 'Jane Doe', assigned_employee_id: 7,
                             assignment_source: 'folder')
      b = invoice('4601.B2', state: 'ready_for_approval', pdf: false, assigned_to: 'Jane Doe', assigned_employee_id: 7,
                             assignment_source: 'folder')

      get :index, params: { queue: 'ready_for_approval' }
      assert_select 'input[type=checkbox][data-aim-move-modal-target=check]', 2
      assert_select 'button[data-action=?]', 'aim-move-modal#openMany'

      patch :reassign_many, params: { queue: 'ready_for_approval', ids: [a.batch_id, b.batch_id], destination: 'shared' }

      assert_match(/Moved 2 invoices/, flash[:notice])
      assert_nil a.reload.assigned_employee_id
      assert_nil b.reload.assigned_employee_id
    end

    test 'a bulk move skips what you could not move one by one' do
      mine = invoice('4601.B3', state: 'ready_for_approval', pdf: false, assigned_to: 'Jane Doe', assigned_employee_id: 7,
                                assignment_source: 'folder')
      theirs = invoice('4601.B4', state: 'ready_for_approval', pdf: false, assigned_to: 'Sam Lee', assigned_employee_id: 8,
                                  assignment_source: 'folder')
      as_owner_not_staff

      patch :reassign_many, params: { queue: 'ready_for_approval', ids: [mine.batch_id, theirs.batch_id], destination: 'shared' }

      assert_match(/Moved 1 invoice\. 1 invoice could not be moved by you/, flash[:notice])
      assert_nil mine.reload.assigned_employee_id
      assert_equal 8, theirs.reload.assigned_employee_id
    end

    # ---------------------------------------------------------------
    # Restoring
    # ---------------------------------------------------------------

    test 'staff restore a rejected invoice to action needed, with the reason kept' do
      row = invoice('4601.RS1', state: 'rejected', pdf: false)

      get :show, params: { id: row.batch_id, queue: 'rejected' }
      assert_select 'form[action=?] button[data-commit=?]', restore_aim_invoice_path(row.batch_id, queue: 'rejected'),
                    'Restore to Action Needed'

      post :restore, params: { id: row.batch_id, queue: 'rejected', invoice_action: 'restore_to_needs_review', reason: 'rejected by mistake' }

      assert_equal 'needs_review', row.reload.state
      assert_match(/Restored from rejected by Aim Staff: rejected by mistake\z/, row.notes)
      assert_equal 'restored from rejected; reason: rejected by mistake', row.events.last.note
    end

    test 'a deleted invoice can go straight back to its owner' do
      row = invoice('4601.RS2', state: 'deleted', pdf: false)

      post :restore, params: { id: row.batch_id, queue: 'deleted', invoice_action: 'restore_to_ready_for_approval', reason: 'still owed' }

      assert_equal 'ready_for_approval', row.reload.state
    end

    test 'restoring needs a reason, and only staff restore' do
      row = invoice('4601.RS3', state: 'deleted', pdf: false)

      post :restore, params: { id: row.batch_id, queue: 'deleted', invoice_action: 'restore_to_needs_review', reason: '' }
      assert_equal 'deleted', row.reload.state
      assert_match(/needs a reason/, flash[:alert])

      as_owner_not_staff
      post :restore, params: { id: row.batch_id, queue: 'deleted', invoice_action: 'restore_to_needs_review', reason: 'x' }
      assert_equal 'deleted', row.reload.state
    end
  end
end
